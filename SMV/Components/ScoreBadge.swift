//
//  ScoreBadge.swift
//  SMV
//
//  Compact score display badge with tier coloring.
//

import SwiftUI

struct ScoreBadge: View {

    let score: Double
    var size: ScoreBadgeSize = .medium

    private var tier: ScoreTier { ScoreTier.from(score: score) }

    var body: some View {
        Text(String(format: "%.1f", score))
            .font(size.font)
            .fontDesign(.monospaced)
            .fontWeight(.bold)
            .foregroundStyle(tier.color)
            .padding(.horizontal, size.hPad)
            .padding(.vertical, size.vPad)
            .background(
                RoundedRectangle(cornerRadius: size.radius)
                    .fill(tier.color.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: size.radius)
                            .stroke(tier.color.opacity(0.3), lineWidth: 1)
                    )
            )
    }
}

enum ScoreBadgeSize {
    case small, medium, large

    var font: Font {
        switch self {
        case .small:  return SMVFont.micro()
        case .medium: return SMVFont.caption()
        case .large:  return SMVFont.title()
        }
    }

    var hPad: CGFloat {
        switch self {
        case .small:  return 6
        case .medium: return 8
        case .large:  return 12
        }
    }

    var vPad: CGFloat {
        switch self {
        case .small:  return 2
        case .medium: return 4
        case .large:  return 6
        }
    }

    var radius: CGFloat {
        switch self {
        case .small:  return 6
        case .medium: return 8
        case .large:  return 10
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        ScoreBadge(score: 9.3, size: .large)
        ScoreBadge(score: 7.8, size: .medium)
        ScoreBadge(score: 5.2, size: .small)
    }
    .padding()
    .background(Color.smvBackground)
}
