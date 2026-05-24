//
//  ShimmerView.swift
//  SMV
//
//  Skeleton loading placeholder with shimmer animation.
//

import SwiftUI

struct ShimmerView: View {

    var cornerRadius: CGFloat = SMVRadius.md
    @State private var phase: CGFloat = 0

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.smvSurface2)
            .overlay(
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    .clear,
                                    Color.white.opacity(0.08),
                                    .clear,
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: -geo.size.width + phase * geo.size.width * 2)
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

// MARK: - Skeleton Presets

struct SkeletonPostCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: SMVSpacing.md) {
            HStack(spacing: SMVSpacing.md) {
                ShimmerView(cornerRadius: SMVRadius.full)
                    .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 4) {
                    ShimmerView()
                        .frame(width: 120, height: 14)
                    ShimmerView()
                        .frame(width: 80, height: 10)
                }
                Spacer()
            }
            ShimmerView(cornerRadius: SMVRadius.md)
                .frame(height: 200)
            ShimmerView()
                .frame(height: 12)
            ShimmerView()
                .frame(width: 200, height: 12)
        }
        .padding(SMVSpacing.lg)
        .background(Color.smvSurface1)
        .clipShape(RoundedRectangle(cornerRadius: SMVRadius.lg))
    }
}

#Preview {
    VStack(spacing: 16) {
        SkeletonPostCard()
        SkeletonPostCard()
    }
    .padding()
    .background(Color.smvBackground)
}
