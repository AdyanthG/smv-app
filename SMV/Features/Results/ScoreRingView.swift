//
//  ScoreRingView.swift
//  SMV
//
//  Animated conic gradient ring with score counter.
//

import SwiftUI

struct ScoreRingView: View {

    let score: Double
    var size: CGFloat = 180
    var animated: Bool = true

    @State private var animatedScore: Double = 0
    @State private var ringProgress: CGFloat = 0

    private var tier: ScoreTier { ScoreTier.from(score: score) }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.smvSurface2, lineWidth: 8)
                .frame(width: size, height: size)

            // Gradient progress ring
            Circle()
                .trim(from: 0, to: ringProgress * CGFloat(score / 10.0))
                .stroke(
                    AngularGradient(
                        colors: [tier.color, tier.color.opacity(0.4), tier.color],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .shadow(color: tier.color.opacity(0.4), radius: 8)

            // Score text
            VStack(spacing: 4) {
                Text(String(format: "%.1f", animatedScore))
                    .font(SMVFont.score())
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())

                Text("SMV SCORE")
                    .font(SMVFont.micro())
                    .foregroundStyle(Color.smvTextSecondary)
                    .tracking(2)
            }
        }
        .onAppear {
            guard animated else {
                animatedScore = score
                ringProgress = 1
                return
            }

            withAnimation(.spring(duration: 1.5, bounce: 0.2)) {
                ringProgress = 1
            }

            // Animate counter
            animateCounter()
        }
    }

    private func animateCounter() {
        let steps = 30
        let interval = 1.2 / Double(steps)
        let increment = score / Double(steps)

        Task { @MainActor in
            for i in 0..<steps {
                try? await Task.sleep(for: .milliseconds(Int(interval * 1000)))
                withAnimation(.linear(duration: interval)) {
                    animatedScore = min(increment * Double(i + 1), score)
                }
            }
            withAnimation(.spring(duration: 0.3)) {
                animatedScore = score
            }
        }
    }
}

#Preview {
    VStack(spacing: 32) {
        ScoreRingView(score: 8.4)
        ScoreRingView(score: 6.2, size: 120)
    }
    .background(Color.smvBackground)
}
