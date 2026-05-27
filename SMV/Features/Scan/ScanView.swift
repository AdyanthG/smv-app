//
//  ScanView.swift
//  SMV
//
//  Face scanning interface: live camera only for authentic, fraud-proof scans.
//

import SwiftUI
import SwiftData

struct ScanView: View {

    @State private var viewModel = ScanViewModel()
    @State private var screenFlashEnabled = false
    @State private var showFlashOverlay = false
    @Environment(Router.self) private var router
    @Environment(HapticService.self) private var haptics
    @Environment(AuthService.self) private var auth
    @Environment(FirestoreService.self) private var firestore
    @Environment(StorageService.self) private var storage
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            Color.smvBackground.ignoresSafeArea()

            switch viewModel.state {
            case .idle:
                scanOptions
            case .cameraActive:
                cameraView
            case .photoSelected(let image):
                photoPreview(image)
            case .analyzing:
                analyzeView
            case .complete(let result):
                completeView(result)
            case .error(let message):
                errorView(message)
            }

            // Screen flash overlay (Snapchat-style front flash)
            if showFlashOverlay {
                Color.white
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Scan Options (Idle)

    private var scanOptions: some View {
        VStack(spacing: SMVSpacing.xxxl) {
            Spacer()

            // Face outline
            ZStack {
                Circle()
                    .stroke(
                        LinearGradient.brandPrimary,
                        style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                    )
                    .frame(width: 200, height: 200)

                Image(systemName: "faceid")
                    .font(.system(size: 64, weight: .thin))
                    .foregroundStyle(
                        LinearGradient.brandPrimary
                    )
            }

            VStack(spacing: SMVSpacing.md) {
                Text("Scan Your Face")
                    .font(SMVFont.displaySmall())
                    .foregroundStyle(.white)

                Text("Use the front camera for an authentic AI-powered analysis")
                    .font(SMVFont.body())
                    .foregroundStyle(Color.smvTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SMVSpacing.xxl)
            }

            VStack(spacing: SMVSpacing.lg) {
                // Camera button
                GradientButton(title: "Start Scan", icon: "camera.fill") {
                    haptics.mediumImpact()
                    viewModel.startCamera()
                }
            }
            .padding(.horizontal, SMVSpacing.xxl)

            // Tips
            GlassmorphicCard(padding: SMVSpacing.md) {
                HStack(spacing: SMVSpacing.md) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(Color.smvAmber)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tips for best results")
                            .font(SMVFont.caption())
                            .foregroundStyle(Color.smvTextPrimary)
                        Text("Good lighting • Front-facing • Neutral expression")
                            .font(SMVFont.micro())
                            .foregroundStyle(Color.smvTextSecondary)
                    }
                }
            }
            .padding(.horizontal, SMVSpacing.xxl)

            Spacer()
        }
    }

    // MARK: - Camera View

    private var cameraView: some View {
        ZStack {
            CameraPreviewView(session: viewModel.captureSession)
                .ignoresSafeArea()

            // Face guide overlay
            VStack {
                Spacer()

                HStack(spacing: SMVSpacing.xxl) {
                    // Close
                    Button {
                        viewModel.stopCamera()
                        viewModel.reset()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .background(Circle().fill(.ultraThinMaterial))
                    }

                    Spacer()

                    // Capture button
                    Button {
                        haptics.mediumImpact()
                        triggerCapture()
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(.white.opacity(0.6), lineWidth: 3)
                                .frame(width: 72, height: 72)
                            Circle()
                                .fill(.white)
                                .frame(width: 60, height: 60)
                        }
                    }

                    Spacer()

                    // Screen flash toggle (replaces upload)
                    Button {
                        screenFlashEnabled.toggle()
                        haptics.lightImpact()
                    } label: {
                        Image(systemName: screenFlashEnabled ? "sun.max.fill" : "sun.max")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(screenFlashEnabled ? Color.smvAmber : .white)
                            .frame(width: 48, height: 48)
                            .background(
                                Circle()
                                    .fill(screenFlashEnabled
                                        ? Color.smvAmber.opacity(0.2)
                                        : Color.clear.opacity(0.001)
                                    )
                                    .overlay(
                                        Circle().fill(.ultraThinMaterial)
                                            .opacity(screenFlashEnabled ? 0 : 1)
                                    )
                            )
                    }
                }
                .padding(.horizontal, SMVSpacing.xxxl)
                .padding(.bottom, 100) // Well above the tab bar
            }
        }
    }

    // MARK: - Screen Flash + Capture

    private func triggerCapture() {
        if screenFlashEnabled {
            // Flash the screen white briefly (Snapchat front-flash effect)
            let originalBrightness = UIScreen.main.brightness
            UIScreen.main.brightness = 1.0
            withAnimation(.easeIn(duration: 0.05)) {
                showFlashOverlay = true
            }

            // Capture after brief flash
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                viewModel.takePhoto()

                withAnimation(.easeOut(duration: 0.3)) {
                    showFlashOverlay = false
                }
                UIScreen.main.brightness = originalBrightness
            }
        } else {
            viewModel.takePhoto()
        }
    }

    // MARK: - Photo Preview

    private func photoPreview(_ image: UIImage) -> some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack {
                Spacer()

                VStack(spacing: SMVSpacing.lg) {
                    GradientButton(title: "Analyze Face", icon: "bolt.fill") {
                        haptics.mediumImpact()
                        Task {
                            await viewModel.analyzeImage(
                                image,
                                userId: auth.currentUserId ?? "local_user",
                                firestore: firestore,
                                storage: storage
                            )
                        }
                    }

                    SecondaryButton(title: "Retake Photo", icon: "arrow.counterclockwise") {
                        viewModel.startCamera()
                    }
                }
                .padding(.horizontal, SMVSpacing.xxl)
                .padding(.bottom, 100) // Above tab bar
            }
        }
    }

    // MARK: - Analyzing

    private var analyzeView: some View {
        ScanAnimationView(progress: viewModel.analysisProgress)
    }

    // MARK: - Complete

    private func completeView(_ result: ScanResult) -> some View {
        VStack(spacing: SMVSpacing.xxl) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.smvEmerald)

            Text("Analysis Complete!")
                .font(SMVFont.displaySmall())
                .foregroundStyle(.white)

            ScoreBadge(score: result.overallScore, size: .large)

            GradientButton(title: "View Results", icon: "chart.bar.fill") {
                haptics.success()
                modelContext.insert(result)
                router.push(.scanResults(scanId: result.id))
            }
            .padding(.horizontal, SMVSpacing.xxl)

            SecondaryButton(title: "Scan Again", icon: "arrow.counterclockwise") {
                viewModel.reset()
            }
            .padding(.horizontal, SMVSpacing.xxl)

            Spacer()
        }
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: SMVSpacing.xxl) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.smvAmber)

            Text("Analysis Failed")
                .font(SMVFont.headline())
                .foregroundStyle(.white)

            Text(message)
                .font(SMVFont.body())
                .foregroundStyle(Color.smvTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SMVSpacing.xxl)

            GradientButton(title: "Try Again", icon: "arrow.counterclockwise") {
                viewModel.reset()
            }
            .padding(.horizontal, SMVSpacing.xxl)

            Spacer()
        }
    }
}

#Preview {
    ScanView()
        .environment(Router())
        .environment(HapticService())
}
