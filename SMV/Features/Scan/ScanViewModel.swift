//
//  ScanViewModel.swift
//  SMV
//
//  Business logic for the face scanning flow.
//

import SwiftUI
import AVFoundation
import Vision
import PhotosUI

@Observable
final class ScanViewModel: NSObject, AVCapturePhotoCaptureDelegate {

    // MARK: - State

    enum ScanState {
        case idle
        case cameraActive
        case photoSelected(UIImage)
        case analyzing
        case complete(ScanResult)
        case error(String)
    }

    var state: ScanState = .idle
    var selectedPhoto: PhotosPickerItem?
    var analysisProgress: Double = 0

    // MARK: - Services

    private let analysisService = FaceAnalysisService()

    // Camera
    let captureSession = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var isSessionConfigured = false
    private var photoContinuation: CheckedContinuation<UIImage?, Never>?

    // MARK: - Camera Setup

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

        // Mirror front camera
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

    // MARK: - Capture Photo

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

    func analyzeImage(_ image: UIImage, userId: String) async {
        state = .analyzing

        let progressTask = Task { @MainActor in
            for step in stride(from: 0.0, through: 0.85, by: 0.01) {
                self.analysisProgress = step
                try? await Task.sleep(for: .milliseconds(30))
            }
        }

        if let result = await analysisService.analyze(image: image, userId: userId) {
            progressTask.cancel()
            withAnimation(.spring(duration: 0.3)) {
                analysisProgress = 1.0
            }
            try? await Task.sleep(for: .milliseconds(500))
            state = .complete(result)
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
    }
}
