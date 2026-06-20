//
//  ResultsView.swift
//  SMV
//
//  Score display with radar chart, attribute breakdown, and improvement tips.
//

import SwiftUI

struct ResultsView: View {

    let scanId: String

    @State private var viewModel = ResultsViewModel()
    @Environment(\.modelContext) private var modelContext
    @Environment(Router.self) private var router
    @Environment(AuthService.self) private var auth
    @Environment(HapticService.self) private var haptics
    @Environment(FirestoreService.self) private var firestore
    @Environment(SubscriptionManager.self) private var subs

    var body: some View {
        ScrollView {
            if let result = viewModel.result {
                VStack(spacing: SMVSpacing.xxxl) {
                    // Score Ring
                    scoreSection(result)

                    // Angle Frames — all available angles, visible to everyone
                    let angles = availableAngles(result)
                    if !angles.isEmpty {
                        angleFramesSection(angles)
                    }

                    // Radar Chart
                    radarSection(result)

                    // Attribute Breakdown
                    attributeSection(result)

                    // Biometric details (Pro)
                    biometricsSection(result)

                    // Actions
                    actionButtons(result)

                    // Improvement Tips
                    tipsSection

                    // Mental health notice
                    wellnessNotice
                }
                .padding(.horizontal, SMVSpacing.lg)
                .padding(.top, SMVSpacing.xl)
                .padding(.bottom, 100)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 200)
            }
        }
        .background(Color.smvBackground)
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await viewModel.loadResult(scanId: scanId, context: modelContext, firestore: firestore)
            haptics.scoreReveal()
        }
        .sheet(isPresented: $viewModel.showShareSheet) {
            if let image = viewModel.shareImage {
                ShareSheet(items: [image])
            }
        }
    }

    // MARK: - Score

    private func scoreSection(_ result: ScanResult) -> some View {
        VStack(spacing: SMVSpacing.lg) {
            ScoreRingView(score: result.overallScore)

            // Tier badge
            HStack(spacing: SMVSpacing.sm) {
                Text(result.tier.emoji)
                Text(result.tier.rawValue)
                    .font(SMVFont.caption())
                    .foregroundStyle(result.tier.color)
            }
            .padding(.horizontal, SMVSpacing.lg)
            .padding(.vertical, SMVSpacing.sm)
            .background(
                Capsule().fill(result.tier.color.opacity(0.15))
            )

            // Delta
            if let delta = viewModel.scoreDelta {
                HStack(spacing: 4) {
                    Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                    Text(delta.deltaFormatted)
                }
                .font(SMVFont.caption())
                .foregroundStyle(delta >= 0 ? Color.smvEmerald : Color.smvPink)
            }
        }
    }
    // MARK: - Angle Frames

    /// Canonical angle ordering, filtered to angles that actually have an image
    /// (local data or remote URL). All 5 angles are visible to every viewer.
    private func availableAngles(_ result: ScanResult) -> [ScanAngle] {
        let all: [ScanAngle] = [
            ScanAngle(label: "Front", data: result.imageData, index: 0),
            ScanAngle(label: "Left", data: result.leftImageData, index: 1),
            ScanAngle(label: "Right", data: result.rightImageData, index: 2),
            ScanAngle(label: "Up", data: result.upImageData, index: 3),
            ScanAngle(label: "Down", data: result.downImageData, index: 4),
        ]
        return all.filter { $0.data != nil || remoteAngleURL($0.label) != nil }
    }

    private func angleFramesSection(_ angles: [ScanAngle]) -> some View {
        VStack(alignment: .leading, spacing: SMVSpacing.md) {
            Text("Scan Angles")
                .font(SMVFont.title())
                .foregroundStyle(.white)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SMVSpacing.sm) {
                    ForEach(angles) { angle in
                        Button {
                            router.present(.scanGallery(
                                userId: viewModel.result?.userId ?? "",
                                displayName: "Scan Angles",
                                scanId: scanId,
                                startIndex: angle.index
                            ))
                        } label: {
                            angleFrame(label: angle.label, data: angle.data)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func angleFrame(label: String, data: Data?) -> some View {
        VStack(spacing: SMVSpacing.xs) {
            Group {
                if let data, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else if let url = remoteAngleURL(label) {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        angleFramePlaceholder
                    }
                } else {
                    angleFramePlaceholder
                }
            }
            .frame(width: 80, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: SMVRadius.sm))

            Text(label)
                .font(SMVFont.micro())
                .foregroundStyle(Color.smvTextSecondary)
        }
    }

    private var angleFramePlaceholder: some View {
        RoundedRectangle(cornerRadius: SMVRadius.sm)
            .fill(Color.smvSurface1)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.smvTextTertiary)
            )
    }

    private func remoteAngleURL(_ label: String) -> URL? {
        guard let urlStr = viewModel.remoteAngleURLs?[label] else { return nil }
        return URL(string: urlStr)
    }

    // MARK: - Radar

    private func radarSection(_ result: ScanResult) -> some View {
        GlassmorphicCard {
            RadarChartView(
                attributes: result.attributes.map { ($0.name, $0.score) },
                size: 260
            )
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Attributes

    private func attributeSection(_ result: ScanResult) -> some View {
        VStack(alignment: .leading, spacing: SMVSpacing.lg) {
            Text("Attribute Breakdown")
                .font(SMVFont.headline())
                .foregroundStyle(.white)

            VStack(spacing: SMVSpacing.md) {
                ForEach(result.attributes, id: \.name) { attr in
                    AttributeBar(
                        name: attr.name,
                        icon: iconFor(attr.name),
                        score: attr.score
                    )
                }
            }
        }
    }

    // MARK: - Biometric Details (Pro)

    private func biometricsSection(_ result: ScanResult) -> some View {
        VStack(alignment: .leading, spacing: SMVSpacing.lg) {
            HStack {
                Text("Biometric Details")
                    .font(SMVFont.headline())
                    .foregroundStyle(.white)
                Spacer()
                Text("PRO")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.smvAmber)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(Color.smvAmber.opacity(0.15)))
            }

            if subs.isPro {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: SMVSpacing.md), GridItem(.flexible(), spacing: SMVSpacing.md)], spacing: SMVSpacing.md) {
                    ForEach(metrics(result)) { metric in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(metric.name)
                                .font(SMVFont.micro())
                                .foregroundStyle(Color.smvTextTertiary)
                            Text(metric.value)
                                .font(SMVFont.title())
                                .fontDesign(.rounded)
                                .foregroundStyle(.white)
                            if let ideal = metric.ideal {
                                Text("ideal \(ideal)")
                                    .font(SMVFont.micro())
                                    .foregroundStyle(Color.smvCyan)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(SMVSpacing.md)
                        .background(RoundedRectangle(cornerRadius: SMVRadius.md).fill(Color.smvSurface0))
                    }
                }
            } else {
                Button {
                    haptics.lightImpact()
                    router.present(.paywall)
                } label: {
                    VStack(spacing: SMVSpacing.md) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(Color.smvAmber)
                        Text("Unlock your full biometric breakdown")
                            .font(SMVFont.body())
                            .foregroundStyle(.white)
                        Text("FWHR, canthal tilt, gonial angle, facial thirds & more — the exact PSL measurements.")
                            .font(SMVFont.caption())
                            .foregroundStyle(Color.smvTextSecondary)
                            .multilineTextAlignment(.center)
                        Text("Upgrade to Pro →")
                            .font(SMVFont.caption())
                            .fontWeight(.bold)
                            .foregroundStyle(Color.smvAmber)
                            .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(SMVSpacing.xl)
                    .background(
                        RoundedRectangle(cornerRadius: SMVRadius.lg)
                            .fill(Color.smvSurface0)
                            .overlay(RoundedRectangle(cornerRadius: SMVRadius.lg).stroke(Color.smvAmber.opacity(0.3), lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func metrics(_ r: ScanResult) -> [BioMetric] {
        [
            BioMetric(name: "FWHR", value: String(format: "%.2f", r.fwhr), ideal: "1.90"),
            BioMetric(name: "Canthal Tilt", value: String(format: "%.1f°", r.canthalTiltDegrees), ideal: "+5°"),
            BioMetric(name: "Gonial Angle", value: String(format: "%.0f°", r.gonialAngleDegrees), ideal: "120°"),
            BioMetric(name: "Facial Thirds", value: String(format: "%.1f%%", r.facialThirdsDeviation * 100), ideal: "<5%"),
            BioMetric(name: "IPD Ratio", value: String(format: "%.2f", r.ipdRatio), ideal: "0.46"),
            BioMetric(name: "Symmetry", value: String(format: "%.0f%%", r.rawSymmetry * 100), ideal: "100%"),
            BioMetric(name: "Eye Aspect", value: String(format: "%.2f", r.eyeAspectRatio), ideal: nil),
            BioMetric(name: "Nose Width", value: String(format: "%.2f", r.noseWidthRatio), ideal: nil),
            BioMetric(name: "Lip Ratio", value: String(format: "%.2f", r.lipRatio), ideal: nil),
            BioMetric(name: "Philtrum", value: String(format: "%.2f", r.philtrumRatio), ideal: nil),
        ]
    }

    // MARK: - Actions

    private func actionButtons(_ result: ScanResult) -> some View {
        HStack(spacing: SMVSpacing.md) {
            GradientButton(title: "Scan Again", icon: "camera.fill", isFullWidth: true) {
                router.popToRoot()
                router.switchTab(.scan)
            }

            SecondaryButton(title: "Share", icon: "square.and.arrow.up") {
                haptics.lightImpact()
                viewModel.generateShareCard()
            }
        }
    }

    // MARK: - Tips

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: SMVSpacing.lg) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(Color.smvAmber)
                Text("Improvement Tips")
                    .font(SMVFont.headline())
                    .foregroundStyle(.white)
            }

            VStack(spacing: SMVSpacing.md) {
                ForEach(viewModel.improvementTips, id: \.title) { tip in
                    GlassmorphicCard(padding: SMVSpacing.md) {
                        HStack(alignment: .top, spacing: SMVSpacing.md) {
                            Image(systemName: tip.icon)
                                .font(.system(size: 18))
                                .foregroundStyle(Color.smvCyan)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(tip.title)
                                    .font(SMVFont.title())
                                    .foregroundStyle(.white)
                                Text(tip.description)
                                    .font(SMVFont.caption())
                                    .foregroundStyle(Color.smvTextSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Wellness

    private var wellnessNotice: some View {
        GlassmorphicCard(padding: SMVSpacing.md) {
            HStack(spacing: SMVSpacing.md) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(Color.smvPink)
                VStack(alignment: .leading, spacing: 4) {
                    Text("A note on scores")
                        .font(SMVFont.caption())
                        .foregroundStyle(Color.smvTextPrimary)
                    Text("These scores reflect geometric ratios, not your worth. Beauty is multidimensional and deeply personal.")
                        .font(SMVFont.micro())
                        .foregroundStyle(Color.smvTextTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Icon Mapping

    private func iconFor(_ name: String) -> String {
        switch name {
        case "Eye Area":      return "eye.fill"
        case "Jawline":       return "shield.fill"
        case "Symmetry":      return "arrow.left.and.right"
        case "Harmony":       return "circle.hexagongrid.fill"
        case "Proportions":   return "ruler.fill"
        case "Skin Clarity":  return "sparkles"
        default:              return "circle.fill"
        }
    }
}

// MARK: - Scan Angle

private struct ScanAngle: Identifiable {
    let label: String
    let data: Data?
    let index: Int
    var id: String { label }
}

private struct BioMetric: Identifiable {
    let name: String
    let value: String
    let ideal: String?
    var id: String { name }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        ResultsView(scanId: "preview")
    }
    .environment(Router())
    .environment(HapticService())
    .environment(AuthService())
    .environment(FirestoreService())
    .environment(SubscriptionManager())
}
