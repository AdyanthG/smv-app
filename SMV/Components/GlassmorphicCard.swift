//
//  GlassmorphicCard.swift
//  SMV
//
//  Minimal glass card — sharp edges, subtle surface.
//

import SwiftUI

struct GlassmorphicCard<Content: View>: View {

    var cornerRadius: CGFloat = SMVRadius.md
    var padding: CGFloat = SMVSpacing.lg
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.smvSurface1.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.white.opacity(0.04), lineWidth: 0.5)
                    )
            )
    }
}

#Preview {
    GlassmorphicCard {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Score")
                .font(SMVFont.caption())
                .foregroundStyle(Color.smvTextSecondary)
            Text("5.2")
                .font(SMVFont.score())
                .foregroundStyle(.white)
        }
    }
    .padding()
    .background(Color.smvBackground)
}
