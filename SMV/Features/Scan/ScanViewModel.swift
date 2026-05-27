//
//  ScanViewModel.swift
//  SMV
//
//  Business logic for the face scanning flow.
//  Supports both TrueDepth guided scanning (ARKit) and
//  fallback single-photo mode (AVCaptureSession).
//

import SwiftUI
import AVFoundation
import Vision
import PhotosUI
import ARKit

@Observable
final class ScanViewModel: NSObject, AVCapturePhotoCaptureDelegate {

    // MARK: - State

    enum ScanState {
        case idle
        case cameraActive        // Fallback: simple camera
        case guidedScan          // TrueDepth: guided multi-angle
        case photoSelected(UIImage)
        case analyzing
        case complete(ScanResult)
        case error(String)
    }

    var state: ScanState = .idle
    var selectedPhoto: PhotosPickerItem?
    var analysisProgress: Double = 0

    // Guided scan state
    var faceTracker = FaceTrackingService()
    var isTrueDepthAvailable: Bool { ARFaceTrackingConfiguration.isSupported }

    // MARK: - Services

    private let analysisService = FaceAnalysisService()

    // Camera (fallback)
    let captureSession = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var isSessionConfigured = false
    private var photoContinuation: CheckedContinuation<UIImage?, Never>?

    // MARK: - Camera Setup (Fallback)

    func setupCamera() {
        guard !isSessionConfigured else { return }

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device),
              captureSession.canAddInput(input) else {
            captureSession.commitConfiguration()
            return
        }
        captureSession.addInput(input)

        guard captureSession.canAddOutput(photoOutput) else {
            captureSession.commitConfiguration()
            return
        }
        captureSession.addOutput(photoOutput)

        if let connection = photoOutput.connection(with: .video) {
            connection.isVideoMirrored = true
        }

        captureSession.commitConfiguration()
        isSessionConfigured = true
    }

    func startCamera() {
        setupCamera()
        let session = captureSession
        Task.detached {
            session.startRunning()
        }
        state = .cameraActive
    }

    func stopCamera() {
        let session = captureSession
        Task.detached {
            session.stopRunning()
        }
    }

    // MARK: - Start Scan (chooses mode)

    func startScan() {
        if isTrueDepthAvailable {
            startGuidedScan()
        } else {
            startCamera()
        }
    }

    // MARK: - Guided Scan (TrueDepth)

    func startGuidedScan() {
        faceTracker.reset()
        faceTracker.onCaptureComplete = { [weak self] captures in
            Task { @MainActor in
                self?.handleGuidedCaptureComplete(captures)
            }
        }
        faceTracker.startSession()
        state = .guidedScan
    }

    func stopGuidedScan() {
        faceTracker.stopSession()
    }

    private func handleGuidedCaptureComplete(_ captures: [AngleCapture]) {
        // Use the frontal image for the main analysis
        guard let frontalCapture = captures.first(where: { $0.position == .front }) else {
            state = .error("Failed to capture frontal image")
            return
        }
        // Store captures for depth metric extraction during analysis
        self.pendingCaptures = captures
        state = .photoSelected(frontalCapture.image)
    }

    var pendingCaptures: [AngleCapture]?

    // MARK: - Capture Photo (Fallback)

    func capturePhoto() async -> UIImage? {
        return await withCheckedContinuation { continuation in
            self.photoContinuation = continuation
            let settings = AVCapturePhotoSettings()
            settings.flashMode = .off
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func takePhoto() {
        Task {
            if let image = await capturePhoto() {
                stopCamera()
                state = .photoSelected(image)
            }
        }
    }

    // MARK: - AVCapturePhotoCaptureDelegate

    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let image: UIImage?
        if let data = photo.fileDataRepresentation() {
            image = UIImage(data: data)
        } else {
            image = nil
        }
        Task { @MainActor in
            self.photoContinuation?.resume(returning: image)
            self.photoContinuation = nil
        }
    }

    // MARK: - Photo Selection

    func handlePhotoSelection(_ item: PhotosPickerItem?) async {
        guard let item else { return }

        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                state = .photoSelected(image)
            }
        } catch {
            state = .error("Failed to load photo")
        }
    }

    // MARK: - Analysis

    func analyzeImage(
        _ image: UIImage,
        userId: String,
        firestore: FirestoreService? = nil,
        storage: StorageService? = nil
    ) async {
        state = .analyzing

        let progressTask = Task { @MainActor in
            for step in stride(from: 0.0, through: 0.85, by: 0.01) {
                self.analysisProgress = step
                try? await Task.sleep(for: .milliseconds(30))
            }
        }

        if var result = await analysisService.analyze(image: image, userId: userId) {
            // If we have multi-angle captures, extract 3D metrics and apply
            if let captures = pendingCaptures, !captures.isEmpty {
                let depthMetrics = faceTracker.extract3DMetrics(from: captures)
                // Apply 3D confidence multiplier
                let adjusted = result.overallScore * depthMetrics.confidenceMultiplier
                result.overallScore = adjusted.smvClamped(to: 0.0...10.0)
                // Mark as multi-angle scan
                result.isMultiAngleScan = true
            }

            progressTask.cancel()
            withAnimation(.spring(duration: 0.3)) {
                analysisProgress = 1.0
            }

            // ── Cloud sync (fire-and-forget) ──
            if let firestore, let storage {
                Task {
                    if let imageData = image.jpegData(compressionQuality: 0.7) {
                        let _ = await storage.uploadScanImage(
                            userId: userId,
                            scanId: result.id,
                            imageData: imageData
                        )
                    }
                    let _ = await firestore.saveScanResult(userId: userId, result: result)
                }
            }

            try? await Task.sleep(for: .milliseconds(500))
            state = .complete(result)
            pendingCaptures = nil
        } else {
            progressTask.cancel()
            state = .error(analysisService.errorMessage ?? "Analysis failed")
        }
    }

    // MARK: - Reset

    func reset() {
        state = .idle
        analysisProgress = 0
        selectedPhoto = nil
        pendingCaptures = nil
    }
}
