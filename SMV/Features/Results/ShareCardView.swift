//
//  ShareCardView.swift
//  SMV
//
//  Branded share card for Instagram Stories / social sharing.
//

import SwiftUI

struct ShareCardView: View {

    let result: ScanResult

    private var tier: ScoreTier { result.tier }

    var body: some View {
        VStack(spacing: SMVSpacing.xl) {
            // Header
            HStack {
                HStack(spacing: SMVSpacing.sm) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color.smvViolet)
                    Text("SMV")
                        .font(SMVFont.headline())
                        .foregroundStyle(.white)
                }
                Spacer()
                Text("Know Your Edge")
                    .font(SMVFont.micro())
                    .foregroundStyle(Color.smvTextTertiary)
            }

            // Score
            VStack(spacing: SMVSpacing.md) {
                Text(result.overallScore.scoreFormatted)
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [tier.color, tier.color.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                HStack(spacing: SMVSpacing.sm) {
                    Text(tier.emoji)
                    Text(tier.rawValue)
                        .font(SMVFont.caption())
                        .foregroundStyle(tier.color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(tier.color.opacity(0.15))
                        )
                }
            }

            // Attributes mini-grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
            ], spacing: SMVSpacing.md) {
                ForEach(result.attributes, id: \.name) { attr in
                    VStack(spacing: 4) {
                        Text(attr.score.scoreFormatted)
                            .font(SMVFont.title())
                            .fontDesign(.rounded)
                            .foregroundStyle(.white)
                        Text(attr.name)
                            .font(SMVFont.micro())
                            .foregroundStyle(Color.smvTextTertiary)
                    }
                }
            }

            // Footer
            HStack {
                Text("Scan yours →")
                    .font(SMVFont.caption())
                    .foregroundStyle(Color.smvCyan)
                Spacer()
                Text("smv.app")
                    .font(SMVFont.micro())
                    .foregroundStyle(Color.smvTextTertiary)
            }
        }
        .padding(SMVSpacing.xxl)
        .background(
            RoundedRectangle(cornerRadius: SMVRadius.xl)
                .fill(Color.smvBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: SMVRadius.xl)
                        .stroke(
                            LinearGradient(
                                colors: [tier.color.opacity(0.4), .clear, tier.color.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .frame(width: 350)
    }

    // MARK: - Render to Image

    @MainActor
    func renderToImage() -> UIImage? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = 3.0
        return renderer.uiImage
    }
}

#Preview {
    ShareCardView(result: ScanResult(
        userId: "preview",
        overallScore: 8.4,
        symmetryScore: 8.7,
        jawlineScore: 7.9,
        eyeAreaScore: 9.1,
        skinClarityScore: 7.2,
        harmonyScore: 8.0,
        proportionsScore: 7.8
    ))
    .padding()
    .background(Color.smvSurface0)
}
