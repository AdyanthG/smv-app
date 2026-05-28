//
//  ScanView.swift
//  SMV
//
//  Face scanning interface with TrueDepth guided multi-angle scanning.
//  Falls back to single-photo capture on devices without TrueDepth.
//

import SwiftUI
import SwiftData
import ARKit

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
            case .guidedScan:
                guidedScanView
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

                Text(viewModel.isTrueDepthAvailable
                     ? "Guided multi-angle scan with TrueDepth camera"
                     : "Use the front camera for an AI-powered analysis")
                    .font(SMVFont.body())
                    .foregroundStyle(Color.smvTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SMVSpacing.xxl)
            }

            VStack(spacing: SMVSpacing.lg) {
                GradientButton(title: "Start Scan", icon: "camera.fill") {
                    haptics.mediumImpact()
                    viewModel.startScan(
                        userId: auth.currentUserId,
                        firestore: firestore,
                        storage: storage
                    )
                }
            }
            .padding(.horizontal, SMVSpacing.xxl)

            // Tips
            GlassmorphicCard(padding: SMVSpacing.md) {
                HStack(spacing: SMVSpacing.md) {
                    Image(systemName: viewModel.isTrueDepthAvailable ? "cube.fill" : "lightbulb.fill")
                        .foregroundStyle(viewModel.isTrueDepthAvailable ? Color.smvCyan : Color.smvAmber)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.isTrueDepthAvailable ? "3D Multi-Angle Scan" : "Tips for best results")
                            .font(SMVFont.caption())
                            .foregroundStyle(Color.smvTextPrimary)
                        Text(viewModel.isTrueDepthAvailable
                             ? "Hold 5 positions • Auto-captures • Depth analysis"
                             : "Good lighting • Front-facing • Neutral expression")
                            .font(SMVFont.micro())
                            .foregroundStyle(Color.smvTextSecondary)
                    }
                }
            }
            .padding(.horizontal, SMVSpacing.xxl)

            Spacer()
        }
    }

    // MARK: - Guided Scan View (TrueDepth)

    private var guidedScanView: some View {
        ZStack {
            // AR Camera preview
            ARViewContainer(session: viewModel.faceTracker.arSession, faceTracker: viewModel.faceTracker)
                .ignoresSafeArea()

            // Ring light overlay
            if ringLightEnabled {
                ringLightOverlay
            }

            // Guided overlay
            VStack(spacing: 0) {
                // Top: Position indicator
                VStack(spacing: SMVSpacing.md) {
                    // Progress dots
                    HStack(spacing: SMVSpacing.md) {
                        ForEach(ScanPosition.allCases, id: \.rawValue) { position in
                            Circle()
                                .fill(dotColor(for: position))
                                .frame(width: 10, height: 10)
                                .scaleEffect(position == viewModel.faceTracker.currentPosition ? 1.3 : 1.0)
                                .animation(.spring(duration: 0.3), value: viewModel.faceTracker.currentPosition)
                        }
                    }
                    .padding(.top, 60)

                    Text(viewModel.faceTracker.currentPosition.label)
                        .font(SMVFont.headline())
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .animation(.spring(duration: 0.3), value: viewModel.faceTracker.currentPosition)
                }
                .padding(.horizontal, SMVSpacing.xxl)
                .padding(.vertical, SMVSpacing.lg)
                .background(
                    LinearGradient(
                        colors: [Color.black.opacity(0.7), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                )

                Spacer()

                // Center: Alignment ring
                ZStack {
                    // Outer ring (fills as you hold position)
                    Circle()
                        .trim(from: 0, to: viewModel.faceTracker.alignmentProgress)
                        .stroke(
                            viewModel.faceTracker.isAligned ? Color.smvEmerald : Color.smvCyan,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 220, height: 220)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.1), value: viewModel.faceTracker.alignmentProgress)

                    // Guide ring
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        .frame(width: 220, height: 220)

                    // Direction arrow
                    if viewModel.faceTracker.currentPosition != .front {
                        Image(systemName: viewModel.faceTracker.currentPosition.icon)
                            .font(.system(size: 40, weight: .medium))
                            .foregroundStyle(
                                viewModel.faceTracker.isAligned
                                    ? Color.smvEmerald
                                    : Color.white.opacity(0.8)
                            )
                            .transition(.scale.combined(with: .opacity))
                    }

                    // Face detected indicator
                    if !viewModel.faceTracker.isFaceDetected {
                        VStack(spacing: SMVSpacing.sm) {
                            Image(systemName: "face.dashed")
                                .font(.system(size: 36))
                            Text("Position your face in frame")
                                .font(SMVFont.caption())
                        }
                        .foregroundStyle(Color.smvAmber)
                    }

                    // Debug overlay — real-time angle readout
                    #if DEBUG
                    VStack(alignment: .leading, spacing: 2) {
                        let tracker = viewModel.faceTracker
                        let yawDeg = String(format: "%.1f°", tracker.relativeYaw * 57.3)
                        let pitchDeg = String(format: "%.1f°", tracker.relativePitch * 57.3)
                        let tgtYaw = String(format: "%.1f°", tracker.currentPosition.targetYaw * 57.3)
                        let tgtPitch = String(format: "%.1f°", tracker.currentPosition.targetPitch * 57.3)
                        let tolY = String(format: "%.1f°", tracker.currentPosition.yawTolerance * 57.3)
                        let tolP = String(format: "%.1f°", tracker.currentPosition.pitchTolerance * 57.3)

                        Text("Yaw: \(yawDeg) tgt:\(tgtYaw) ±\(tolY)")
                        Text("Pit: \(pitchDeg) tgt:\(tgtPitch) ±\(tolP)")
                        Text(tracker.isAligned ? "✓ ALIGNED" : "○ seeking…")
                    }
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.green)
                    .padding(6)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(6)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.leading, 8)
                    #endif
                }

                Spacer()

                // Bottom controls
                HStack(spacing: SMVSpacing.xxl) {
                    // Close
                    Button {
                        disableRingLight()
                        viewModel.stopGuidedScan()
                        viewModel.reset()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .background(Circle().fill(.ultraThinMaterial))
                    }

                    Spacer()

                    // Status text
                    VStack(spacing: SMVSpacing.xs) {
                        Text("\(viewModel.faceTracker.captures.count)/5")
                            .font(SMVFont.title())
                            .foregroundStyle(.white)
                        Text("captured")
                            .font(SMVFont.micro())
                            .foregroundStyle(Color.smvTextTertiary)
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
                .padding(.bottom, 100)
            }
        }
    }

    private func dotColor(for position: ScanPosition) -> Color {
        if viewModel.faceTracker.captures.contains(where: { $0.position == position }) {
            return Color.smvEmerald
        }
        if position == viewModel.faceTracker.currentPosition {
            return Color.smvCyan
        }
        return Color.smvSurface2
    }

    // MARK: - Camera View (Fallback)

    private var cameraView: some View {
        ZStack {
            CameraPreviewView(session: viewModel.captureSession)
                .ignoresSafeArea()

            if ringLightEnabled {
                ringLightOverlay
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
                .padding(.bottom, 100)
            }
        }
    }

    // MARK: - Ring Light Overlay

    private var ringLightOverlay: some View {
        // Full-screen white flash (Snapchat-style)
        // Uses a bright white fill covering the entire screen
        // with a soft radial gradient cutout so the face is still visible
        ZStack {
            // Primary white fill — max brightness
            Color.white
                .ignoresSafeArea()

            // Subtle radial gradient so the face area isn't blown out
            // but the surrounding screen is pure white
            RadialGradient(
                colors: [
                    Color.white.opacity(0.6),
                    Color.white.opacity(0.85),
                    Color.white
                ],
                center: .center,
                startRadius: 80,
                endRadius: 250
            )
            .ignoresSafeArea()
        }
        .allowsHitTesting(false)
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
                // Multi-angle badge
                if viewModel.pendingCaptures != nil {
                    HStack(spacing: SMVSpacing.sm) {
                        Image(systemName: "cube.fill")
                            .foregroundStyle(Color.smvCyan)
                        Text("5-Angle 3D Scan")
                            .font(SMVFont.caption())
                            .foregroundStyle(Color.smvCyan)
                    }
                    .padding(.horizontal, SMVSpacing.md)
                    .padding(.vertical, SMVSpacing.sm)
                    .background(Capsule().fill(Color.smvCyan.opacity(0.15)))
                    .padding(.top, 60)
                }

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
                        viewModel.startScan(
                            userId: auth.currentUserId,
                            firestore: firestore,
                            storage: storage
                        )
                    }
                }
                .padding(.horizontal, SMVSpacing.xxl)
                .padding(.bottom, 100)
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

            if result.isMultiAngleScan {
                HStack(spacing: SMVSpacing.sm) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color.smvEmerald)
                    Text("3D Verified Scan")
                        .font(SMVFont.caption())
                        .foregroundStyle(Color.smvEmerald)
                }
                .padding(.horizontal, SMVSpacing.md)
                .padding(.vertical, SMVSpacing.sm)
                .background(Capsule().fill(Color.smvEmerald.opacity(0.15)))
            }

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

// MARK: - AR View Container (wraps ARSCNView for SwiftUI)

struct ARViewContainer: UIViewRepresentable {
    let session: ARSession
    let faceTracker: FaceTrackingService

    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView()
        arView.session = session
        arView.automaticallyUpdatesLighting = true
        arView.scene = SCNScene()
        arView.rendersContinuously = true
        // Wire so FaceTrackingService can use snapshot() for image capture
        faceTracker.arView = arView
        return arView
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // Session is managed externally
    }
}

#Preview {
    ScanView()
        .environment(Router())
        .environment(HapticService())
}
