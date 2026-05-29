//
//  AvatarView.swift
//  SMV
//
//  User avatar with gradient tier ring and initials fallback.
//

import SwiftUI

struct AvatarView: View {

    let name: String
    var avatarURL: String? = nil
    var score: Double? = nil
    var size: CGFloat = 48

    private var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        return parts.map { String($0.prefix(1)).uppercased() }.joined()
    }

    private var ringColors: [Color] {
        guard let score else { return [.smvSurface2, .smvSurface2] }
        let tier = ScoreTier.from(score: score)
        return [tier.color, tier.color.opacity(0.5)]
    }

    var body: some View {
        ZStack {
            // Ring
            Circle()
                .stroke(
                    LinearGradient(colors: ringColors, startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: size * 0.06
                )
                .frame(width: size, height: size)

            // Avatar content
            if let avatarURL, let url = URL(string: avatarURL) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    initialsView
                }
                .frame(width: size * 0.85, height: size * 0.85)
                .clipShape(Circle())
            } else {
                initialsView
            }
        }
    }

    private var initialsView: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [.smvViolet.opacity(0.5), .smvCyan.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size * 0.85, height: size * 0.85)
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.3, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            )
    }
}

#Preview {
    HStack(spacing: 16) {
        AvatarView(name: "Alex Chen", score: 9.2, size: 64)
        AvatarView(name: "Jordan Smith", score: 7.8, size: 48)
        AvatarView(name: "Riley", size: 40)
    }
    .padding()
    .background(Color.smvBackground)
}
