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
    @Environment(HapticService.self) private var haptics

    var body: some View {
        ScrollView {
            if let result = viewModel.result {
                VStack(spacing: SMVSpacing.xxxl) {
                    // Score Ring
                    scoreSection(result)

                    // Radar Chart
                    radarSection(result)

                    // Attribute Breakdown
                    attributeSection(result)

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
        .onAppear {
            viewModel.loadResult(scanId: scanId, context: modelContext)
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
}
