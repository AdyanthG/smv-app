//
//  UserProfileView.swift
//  SMV
//
//  Public profile — viewed when tapping a user in leaderboard or feed.
//

import SwiftUI

struct UserProfileView: View {

    let userId: String
    let displayName: String
    let score: Double
    var handle: String = ""

    private var tier: ScoreTier { ScoreTier.from(score: score) }

    var body: some View {
        ScrollView {
            VStack(spacing: SMVSpacing.xxl) {
                // Hero
                VStack(spacing: SMVSpacing.lg) {
                    // Avatar
                    ZStack {
                        Circle()
                            .fill(Color.smvSurface2)
                            .frame(width: 88, height: 88)
                            .overlay(
                                Circle()
                                    .stroke(tier.color.opacity(0.3), lineWidth: 1)
                            )
                        Text(displayName.prefix(1).uppercased())
                            .font(SMVFont.displaySmall())
                            .foregroundStyle(tier.color)
                    }

                    VStack(spacing: SMVSpacing.xs) {
                        Text(displayName)
                            .font(SMVFont.headline())
                            .foregroundStyle(.white)
                        if !handle.isEmpty {
                            Text("@\(handle)")
                                .font(SMVFont.caption())
                                .foregroundStyle(Color.smvTextTertiary)
                        }
                    }

                    // Score
                    VStack(spacing: SMVSpacing.xs) {
                        Text(score.scoreFormatted)
                            .font(SMVFont.score())
                            .foregroundStyle(tier.color)

                        HStack(spacing: SMVSpacing.sm) {
                            Text(tier.emoji)
                            Text(tier.rawValue)
                                .font(SMVFont.caption())
                                .foregroundStyle(tier.color)
                        }
                        .padding(.horizontal, SMVSpacing.md)
                        .padding(.vertical, SMVSpacing.xs)
                        .background(
                            Capsule().fill(tier.color.opacity(0.1))
                        )
                    }
                }
                .padding(.top, SMVSpacing.xxl)

                // Stats
                HStack(spacing: 0) {
                    statItem(value: "12", label: "Scans")
                    Divider()
                        .frame(height: 32)
                        .overlay(Color.smvSurface2)
                    statItem(value: tier.rarity, label: "Rarity")
                    Divider()
                        .frame(height: 32)
                        .overlay(Color.smvSurface2)
                    statItem(value: "7", label: "Streak")
                }
                .padding(.vertical, SMVSpacing.lg)
                .background(Color.smvSurface0)

                // Actions
                HStack(spacing: SMVSpacing.md) {
                    SecondaryButton(title: "Follow", icon: "plus") { }
                    SecondaryButton(title: "Share", icon: "square.and.arrow.up") { }
                }
                .padding(.horizontal, SMVSpacing.xxl)

                // Recent scans placeholder
                VStack(alignment: .leading, spacing: SMVSpacing.md) {
                    Text("RECENT SCANS")
                        .font(SMVFont.micro())
                        .foregroundStyle(Color.smvTextTertiary)
                        .tracking(1)

                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: SMVSpacing.sm),
                        GridItem(.flexible(), spacing: SMVSpacing.sm),
                        GridItem(.flexible(), spacing: SMVSpacing.sm),
                    ], spacing: SMVSpacing.sm) {
                        ForEach(0..<6, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: SMVRadius.sm)
                                .fill(Color.smvSurface1)
                                .aspectRatio(1, contentMode: .fit)
                                .overlay(
                                    Image(systemName: "viewfinder")
                                        .foregroundStyle(Color.smvTextTertiary.opacity(0.5))
                                )
                        }
                    }
                }
                .padding(.horizontal, SMVSpacing.xxl)
            }
        }
        .background(Color.smvBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: SMVSpacing.xs) {
            Text(value)
                .font(SMVFont.title())
                .foregroundStyle(.white)
            Text(label)
                .font(SMVFont.micro())
                .foregroundStyle(Color.smvTextTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}
