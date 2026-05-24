//
//  ScanView.swift
//  SMV
//
//  Face scanning interface: camera preview, upload, and analysis.
//

import SwiftUI
import SwiftData
import PhotosUI

struct ScanView: View {

    @State private var viewModel = ScanViewModel()
    @Environment(Router.self) private var router
    @Environment(HapticService.self) private var haptics
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
        }
        .onChange(of: viewModel.selectedPhoto) { _, newValue in
            Task {
                await viewModel.handlePhotoSelection(newValue)
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

                Text("Take a photo or upload one to get your AI-powered analysis")
                    .font(SMVFont.body())
                    .foregroundStyle(Color.smvTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SMVSpacing.xxl)
            }

            VStack(spacing: SMVSpacing.lg) {
                // Camera button
                GradientButton(title: "Use Camera", icon: "camera.fill") {
                    haptics.mediumImpact()
                    viewModel.startCamera()
                }

                // Photo picker
                PhotosPicker(
                    selection: $viewModel.selectedPhoto,
                    matching: .images
                ) {
                    HStack(spacing: SMVSpacing.sm) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Upload Photo")
                            .font(SMVFont.title())
                    }
                    .foregroundStyle(Color.smvTextPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SMVSpacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: SMVRadius.xl)
                            .fill(Color.smvSurface2)
                            .overlay(
                                RoundedRectangle(cornerRadius: SMVRadius.xl)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
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
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(.ultraThinMaterial))
                    }

                    Spacer()

                    // Real capture button
                    Button {
                        haptics.mediumImpact()
                        viewModel.takePhoto()
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

                    // Gallery picker
                    PhotosPicker(
                        selection: $viewModel.selectedPhoto,
                        matching: .images
                    ) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                }
                .padding(.horizontal, SMVSpacing.xxl)
                .padding(.bottom, SMVSpacing.huge)
            }
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
                            await viewModel.analyzeImage(image, userId: "local_user")
                        }
                    }

                    SecondaryButton(title: "Choose Different Photo", icon: "arrow.counterclockwise") {
                        viewModel.reset()
                    }
                }
                .padding(.horizontal, SMVSpacing.xxl)
                .padding(.bottom, SMVSpacing.huge)
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
