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
    @State private var ringLightEnabled = false
    @State private var captureFlash = false
    @State private var savedBrightness: CGFloat = 0.5
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

            // Brief full-screen white flash on capture
            if captureFlash {
                Color.white
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .allowsHitTesting(false)
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

            // ── Persistent Ring Light ──
            // Bright white border around the entire screen edge,
            // acts as a soft light source for the front camera.
            if ringLightEnabled {
                Rectangle()
                    .fill(.clear)
                    .ignoresSafeArea()
                    .overlay(
                        RoundedRectangle(cornerRadius: 0)
                            .stroke(Color.white.opacity(0.95), lineWidth: 60)
                            .blur(radius: 20)
                            .ignoresSafeArea()
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 0)
                            .stroke(Color.white, lineWidth: 30)
                            .ignoresSafeArea()
                    )
                    .allowsHitTesting(false)
            }

            // Controls
            VStack {
                Spacer()

                HStack(spacing: SMVSpacing.xxl) {
                    // Close
                    Button {
                        disableRingLight()
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

                    // Ring light toggle
                    Button {
                        toggleRingLight()
                    } label: {
                        Image(systemName: ringLightEnabled ? "sun.max.fill" : "sun.max")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(ringLightEnabled ? Color.smvAmber : .white)
                            .frame(width: 48, height: 48)
                            .background(
                                Circle()
                                    .fill(ringLightEnabled
                                        ? Color.smvAmber.opacity(0.25)
                                        : Color.clear.opacity(0.001)
                                    )
                                    .overlay(
                                        Circle().fill(.ultraThinMaterial)
                                            .opacity(ringLightEnabled ? 0 : 1)
                                    )
                            )
                    }
                }
                .padding(.horizontal, SMVSpacing.xxxl)
                .padding(.bottom, 100) // Well above the tab bar
            }
        }
    }

    // MARK: - Ring Light Controls

    private func toggleRingLight() {
        haptics.lightImpact()
        if ringLightEnabled {
            disableRingLight()
        } else {
            enableRingLight()
        }
    }

    private func enableRingLight() {
        savedBrightness = UIScreen.main.brightness
        UIScreen.main.brightness = 1.0
        withAnimation(.easeIn(duration: 0.2)) {
            ringLightEnabled = true
        }
    }

    private func disableRingLight() {
        UIScreen.main.brightness = savedBrightness
        withAnimation(.easeOut(duration: 0.2)) {
            ringLightEnabled = false
        }
    }

    // MARK: - Capture

    private func triggerCapture() {
        if ringLightEnabled {
            // Brief full-screen flash for the actual capture moment
            withAnimation(.easeIn(duration: 0.05)) {
                captureFlash = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                viewModel.takePhoto()
                withAnimation(.easeOut(duration: 0.25)) {
                    captureFlash = false
                }
                disableRingLight()
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
