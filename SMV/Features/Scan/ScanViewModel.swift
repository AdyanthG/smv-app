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

    func startScan(
        userId: String? = nil,
        firestore: FirestoreService? = nil,
        storage: StorageService? = nil
    ) {
        if isTrueDepthAvailable {
            startGuidedScan(userId: userId, firestore: firestore, storage: storage)
        } else {
            startCamera()
        }
    }

    // MARK: - Guided Scan (TrueDepth)

    /// Store references so guided scan auto-analyze can use them
    private var guidedUserId: String?
    private var guidedFirestore: FirestoreService?
    private var guidedStorage: StorageService?

    func startGuidedScan(
        userId: String? = nil,
        firestore: FirestoreService? = nil,
        storage: StorageService? = nil
    ) {
        // Store refs for auto-analyze after capture completes
        guidedUserId = userId
        guidedFirestore = firestore
        guidedStorage = storage

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

        // Auto-analyze — skip preview step for seamless UX
        let image = frontalCapture.image
        let userId = guidedUserId ?? "local_user"
        Task {
            await analyzeImage(
                image,
                userId: userId,
                firestore: guidedFirestore,
                storage: guidedStorage
            )
        }
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

        // ── Multi-angle analysis ──
        // Analyze every captured angle, not just frontal.
        // Each angle reveals different features:
        //   Front  → symmetry, proportions, eye area
        //   Left/Right → jawline definition, nose profile, cheekbone projection
        //   Up/Down → forehead proportions, chin projection, under-eye area

        if let captures = pendingCaptures, captures.count >= 3 {
            // Analyze each capture
            var angleResults: [(position: ScanPosition, result: ScanResult)] = []

            for (index, capture) in captures.enumerated() {
                // Update progress for each angle
                await MainActor.run {
                    let base = 0.1 + Double(index) * 0.15
                    self.analysisProgress = min(0.85, base)
                }

                let isAngled = capture.position != .front
                if let result = await analysisService.analyze(image: capture.image, userId: userId, isAngled: isAngled) {
                    angleResults.append((position: capture.position, result: result))
                }
            }

            guard !angleResults.isEmpty else {
                progressTask.cancel()
                state = .error(analysisService.errorMessage ?? "Analysis failed — no face detected in any angle")
                return
            }

            // ── Weighted score combination ──
            // Front: 40% (primary face — symmetry, proportions)
            // Left/Right: 20% each (profile — jawline, nose, cheekbones)
            // Up/Down: 10% each (vertical — forehead, chin)
            var weightedScore: Double = 0
            var totalWeight: Double = 0

            for (position, result) in angleResults {
                let weight: Double
                switch position {
                case .front: weight = 0.40
                case .left:  weight = 0.20
                case .right: weight = 0.20
                case .up:    weight = 0.10
                case .down:  weight = 0.10
                }
                weightedScore += result.overallScore * weight
                totalWeight += weight
            }

            // Normalize if not all angles were captured
            let combinedScore = totalWeight > 0 ? weightedScore / totalWeight : 0

            // Use the frontal result as the base (for sub-scores and categories),
            // but replace the overall score with the multi-angle combined score
            if var baseResult = angleResults.first(where: { $0.position == .front })?.result
                                ?? angleResults.first?.result {

                // Apply 3D depth metrics if available
                let depthMetrics = faceTracker.extract3DMetrics(from: captures)
                let adjusted = combinedScore * depthMetrics.confidenceMultiplier
                baseResult.overallScore = adjusted.smvClamped(to: 0.0...10.0)
                baseResult.isMultiAngleScan = true

                // ── Store all 5 angle images ──
                for capture in captures {
                    let jpegData = capture.image.jpegData(compressionQuality: 0.7)
                    switch capture.position {
                    case .front: baseResult.imageData = jpegData
                    case .left:  baseResult.leftImageData = jpegData
                    case .right: baseResult.rightImageData = jpegData
                    case .up:    baseResult.upImageData = jpegData
                    case .down:  baseResult.downImageData = jpegData
                    }
                }

                progressTask.cancel()
                withAnimation(.spring(duration: 0.3)) {
                    analysisProgress = 1.0
                }

                // ── Cloud sync ──
                if let firestore, let storage {
                    Task {
                        // Upload all angle images
                        for capture in captures {
                            if let imageData = capture.image.jpegData(compressionQuality: 0.7) {
                                let suffix = capture.position == .front ? "" : "_\(capture.position)"
                                let _ = await storage.uploadScanImage(
                                    userId: userId,
                                    scanId: baseResult.id + suffix,
                                    imageData: imageData
                                )
                            }
                        }

                        // Save scan result
                        let _ = await firestore.saveScanResult(userId: userId, result: baseResult)

                        // Update user profile so they appear on leaderboard
                        let displayName = UserDefaults.standard.string(forKey: "smv_displayName") ?? "User"
                        await firestore.saveUserProfile(
                            userId: userId,
                            displayName: displayName,
                            latestScore: baseResult.overallScore
                        )
                    }
                }

                try? await Task.sleep(for: .milliseconds(500))
                state = .complete(baseResult)
                pendingCaptures = nil
                return
            }
        }

        // ── Fallback: single image analysis (no multi-angle captures) ──
        if var result = await analysisService.analyze(image: image, userId: userId) {
            progressTask.cancel()
            withAnimation(.spring(duration: 0.3)) {
                analysisProgress = 1.0
            }

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

                    // Update user profile so they appear on leaderboard
                    let displayName = UserDefaults.standard.string(forKey: "smv_displayName") ?? "User"
                    await firestore.saveUserProfile(
                        userId: userId,
                        displayName: displayName,
                        latestScore: result.overallScore
                    )
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
