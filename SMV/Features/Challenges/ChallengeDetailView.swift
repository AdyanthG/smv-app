//
//  ChallengeDetailView.swift
//  SMV
//
//  Full detail view for a specific challenge.
//

import SwiftUI

struct ChallengeDetailView: View {

    let challengeId: String

    @Environment(HapticService.self) private var haptics
    @State private var isJoined = false

    private var challenge: ChallengeData? {
        (ChallengeData.active + ChallengeData.upcoming).first { $0.id == challengeId }
    }

    var body: some View {
        ScrollView {
            if let challenge {
                VStack(spacing: SMVSpacing.xxl) {
                    // Hero
                    VStack(spacing: SMVSpacing.lg) {
                        Text(challenge.emoji)
                            .font(.system(size: 56))

                        Text(challenge.title)
                            .font(SMVFont.displaySmall())
                            .foregroundStyle(.white)

                        Text(challenge.subtitle)
                            .font(SMVFont.body())
                            .foregroundStyle(Color.smvTextSecondary)
                    }
                    .padding(.top, SMVSpacing.xxl)

                    // Stats bar
                    HStack(spacing: 0) {
                        statItem(value: "\(challenge.participants)", label: "Joined")
                        Divider()
                            .frame(height: 32)
                            .overlay(Color.smvSurface2)
                        statItem(value: challenge.reward, label: "Reward")
                        Divider()
                            .frame(height: 32)
                            .overlay(Color.smvSurface2)
                        statItem(
                            value: challenge.progress > 0 ? "\(Int(challenge.progress * 100))%" : "—",
                            label: "Progress"
                        )
                    }
                    .padding(.vertical, SMVSpacing.lg)
                    .background(Color.smvSurface0)

                    // Description
                    VStack(alignment: .leading, spacing: SMVSpacing.md) {
                        Text("ABOUT")
                            .font(SMVFont.micro())
                            .foregroundStyle(Color.smvTextTertiary)
                            .tracking(1)

                        Text(challenge.description)
                            .font(SMVFont.body())
                            .foregroundStyle(Color.smvTextSecondary)
                            .lineSpacing(4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, SMVSpacing.xxl)

                    // Rules
                    VStack(alignment: .leading, spacing: SMVSpacing.md) {
                        Text("RULES")
                            .font(SMVFont.micro())
                            .foregroundStyle(Color.smvTextTertiary)
                            .tracking(1)

                        ForEach(challenge.rules, id: \.self) { rule in
                            HStack(alignment: .top, spacing: SMVSpacing.md) {
                                Circle()
                                    .fill(challenge.accentColor)
                                    .frame(width: 6, height: 6)
                                    .padding(.top, 6)
                                Text(rule)
                                    .font(SMVFont.caption())
                                    .foregroundStyle(Color.smvTextSecondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, SMVSpacing.xxl)

                    // Progress (if joined)
                    if challenge.progress > 0 {
                        VStack(alignment: .leading, spacing: SMVSpacing.md) {
                            Text("YOUR PROGRESS")
                                .font(SMVFont.micro())
                                .foregroundStyle(Color.smvTextTertiary)
                                .tracking(1)

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.smvSurface2)
                                        .frame(height: 8)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(challenge.accentColor)
                                        .frame(width: geo.size.width * challenge.progress, height: 8)
                                }
                            }
                            .frame(height: 8)

                            Text("\(Int(challenge.progress * 100))% complete")
                                .font(SMVFont.caption())
                                .foregroundStyle(challenge.accentColor)
                        }
                        .padding(.horizontal, SMVSpacing.xxl)
                    }

                    // Join button
                    if isJoined {
                        SecondaryButton(title: "Leave Challenge", icon: "xmark") {
                            haptics.mediumImpact()
                            isJoined = false
                        }
                        .padding(.horizontal, SMVSpacing.xxl)
                    } else {
                        GradientButton(title: "Join Challenge", icon: "plus") {
                            haptics.success()
                            isJoined = true
                        }
                        .padding(.horizontal, SMVSpacing.xxl)
                    }

                    // Leaderboard preview
                    VStack(alignment: .leading, spacing: SMVSpacing.md) {
                        Text("TOP PARTICIPANTS")
                            .font(SMVFont.micro())
                            .foregroundStyle(Color.smvTextTertiary)
                            .tracking(1)

                        ForEach(sampleParticipants.indices, id: \.self) { i in
                            let p = sampleParticipants[i]
                            HStack(spacing: SMVSpacing.md) {
                                Text("#\(i + 1)")
                                    .font(SMVFont.monoSmall())
                                    .foregroundStyle(i < 3 ? Color.smvAmber : Color.smvTextTertiary)
                                    .frame(width: 30)

                                ZStack {
                                    Circle()
                                        .fill(Color.smvSurface2)
                                        .frame(width: 32, height: 32)
                                    Text(p.name.prefix(1).uppercased())
                                        .font(SMVFont.caption())
                                        .foregroundStyle(.white)
                                }

                                Text(p.name)
                                    .font(SMVFont.caption())
                                    .foregroundStyle(.white)

                                Spacer()

                                Text(String(format: "%.1f", p.score))
                                    .font(SMVFont.monoSmall())
                                    .foregroundStyle(ScoreTier.from(score: p.score).color)
                            }
                            .padding(.vertical, SMVSpacing.xs)
                        }
                    }
                    .padding(.horizontal, SMVSpacing.xxl)
                    .padding(.bottom, SMVSpacing.xxxl)
                }
            } else {
                VStack(spacing: SMVSpacing.lg) {
                    Spacer()
                    Image(systemName: "trophy")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.smvTextTertiary)
                    Text("Challenge not found")
                        .font(SMVFont.title())
                        .foregroundStyle(Color.smvTextSecondary)
                    Spacer()
                }
            }
        }
        .background(Color.smvBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
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

    private var sampleParticipants: [(name: String, score: Double)] {
        [
            ("Elena V.", 8.4),
            ("Marcus T.", 8.1),
            ("Aria Chen", 7.9),
            ("Dev Patel", 7.6),
            ("Lily Rose", 7.4),
        ]
    }
}
