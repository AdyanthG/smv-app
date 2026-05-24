//
//  AttributeBar.swift
//  SMV
//
//  Animated horizontal score bar with icon and label.
//

import SwiftUI

struct AttributeBar: View {

    let name: String
    let icon: String
    let score: Double
    var maxScore: Double = 10.0
    var animated: Bool = true

    @State private var animatedProgress: CGFloat = 0

    private var tier: ScoreTier { ScoreTier.from(score: score) }
    private var progress: CGFloat { CGFloat(score / maxScore) }

    var body: some View {
        HStack(spacing: SMVSpacing.md) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(tier.color)
                .frame(width: 20)

            // Label
            Text(name)
                .font(SMVFont.body())
                .foregroundStyle(Color.smvTextPrimary)

            Spacer()

            // Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.smvSurface2)
                        .frame(height: 6)

                    // Fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [tier.color, tier.color.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * animatedProgress, height: 6)
                }
            }
            .frame(height: 6)
            .frame(maxWidth: 140)

            // Score
            Text(String(format: "%.1f", score))
                .font(SMVFont.caption())
                .fontDesign(.rounded)
                .fontWeight(.bold)
                .foregroundStyle(tier.color)
                .frame(width: 32, alignment: .trailing)
        }
        .onAppear {
            if animated {
                withAnimation(.spring(duration: 0.8, bounce: 0.2).delay(0.1)) {
                    animatedProgress = progress
                }
            } else {
                animatedProgress = progress
            }
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        AttributeBar(name: "Symmetry", icon: "arrow.left.and.right", score: 8.7)
        AttributeBar(name: "Jawline", icon: "shield.fill", score: 7.2)
        AttributeBar(name: "Eye Area", icon: "eye.fill", score: 9.1)
        AttributeBar(name: "Skin Clarity", icon: "sparkles", score: 6.5)
    }
    .padding()
    .background(Color.smvBackground)
}
