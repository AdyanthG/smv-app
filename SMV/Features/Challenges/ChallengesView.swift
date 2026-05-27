//
//  ChallengesView.swift
//  SMV
//
//  Browse active and upcoming challenges.
//

import SwiftUI

struct ChallengesView: View {

    @Environment(Router.self) private var router

    private let activeChallenges = ChallengeData.active
    private let upcomingChallenges = ChallengeData.upcoming

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SMVSpacing.xxl) {
                // Active
                VStack(alignment: .leading, spacing: SMVSpacing.md) {
                    Text("ACTIVE CHALLENGES")
                        .font(SMVFont.micro())
                        .foregroundStyle(Color.smvTextTertiary)
                        .tracking(1)

                    ForEach(activeChallenges) { challenge in
                        Button {
                        router.push(.challengeDetail(challengeId: challenge.id))
                        } label: {
                            challengeCard(challenge, isActive: true)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Upcoming
                VStack(alignment: .leading, spacing: SMVSpacing.md) {
                    Text("UPCOMING")
                        .font(SMVFont.micro())
                        .foregroundStyle(Color.smvTextTertiary)
                        .tracking(1)

                    ForEach(upcomingChallenges) { challenge in
                        challengeCard(challenge, isActive: false)
                    }
                }
            }
            .padding(.horizontal, SMVSpacing.xxl)
            .padding(.top, SMVSpacing.xxl)
        }
        .background(Color.smvBackground)
        .navigationTitle("Challenges")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func challengeCard(_ challenge: ChallengeData, isActive: Bool) -> some View {
        VStack(alignment: .leading, spacing: SMVSpacing.md) {
            HStack {
                Text(challenge.emoji)
                    .font(.system(size: 28))
                VStack(alignment: .leading, spacing: SMVSpacing.xs) {
                    Text(challenge.title)
                        .font(SMVFont.title())
                        .foregroundStyle(.white)
                    Text(challenge.subtitle)
                        .font(SMVFont.caption())
                        .foregroundStyle(Color.smvTextSecondary)
                }
                Spacer()
                if isActive {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Color.smvTextTertiary)
                }
            }

            if isActive {
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.smvSurface2)
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(challenge.accentColor)
                            .frame(width: geo.size.width * challenge.progress, height: 4)
                    }
                }
                .frame(height: 4)

                HStack {
                    Text("\(Int(challenge.progress * 100))% complete")
                        .font(SMVFont.micro())
                        .foregroundStyle(Color.smvTextTertiary)
                    Spacer()
                    Text(challenge.reward)
                        .font(SMVFont.micro())
                        .foregroundStyle(challenge.accentColor)
                }
            } else {
                HStack {
                    Text("Starts \(challenge.startDate)")
                        .font(SMVFont.micro())
                        .foregroundStyle(Color.smvTextTertiary)
                    Spacer()
                    Text(challenge.reward)
                        .font(SMVFont.micro())
                        .foregroundStyle(Color.smvAmber)
                }
            }
        }
        .padding(SMVSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: SMVRadius.md)
                .fill(Color.smvSurface0)
                .overlay(
                    RoundedRectangle(cornerRadius: SMVRadius.md)
                        .stroke(Color.smvSurface2, lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Challenge Data

struct ChallengeData: Identifiable {
    let id: String
    let emoji: String
    let title: String
    let subtitle: String
    let description: String
    let reward: String
    let progress: Double
    let accentColor: Color
    let startDate: String
    let participants: Int
    let rules: [String]

    static let active: [ChallengeData] = [
        ChallengeData(
            id: "streak7",
            emoji: "🔥",
            title: "7-Day Streak",
            subtitle: "Scan every day for a week",
            description: "Consistency is key. Scan your face every single day for 7 days straight to complete this challenge. Track how your score changes with daily lighting, sleep, and skincare habits.",
            reward: "🏆 Streak Badge",
            progress: 0.43,
            accentColor: .smvAmber,
            startDate: "",
            participants: 1247,
            rules: ["Scan once per day", "Must be 7 consecutive days", "Score is recorded automatically"]
        ),
        ChallengeData(
            id: "glowup",
            emoji: "✨",
            title: "Skincare Glow Up",
            subtitle: "Improve your skin clarity score by +1.0",
            description: "Focus on your skincare routine this month. The goal is to measurably improve your skin clarity sub-score by at least 1.0 points from your baseline. Take before/after scans to track progress.",
            reward: "💎 +1 Week Pro",
            progress: 0.20,
            accentColor: .smvEmerald,
            startDate: "",
            participants: 892,
            rules: ["Baseline scan required", "Improvement measured from first to last scan", "Minimum 5 scans required"]
        ),
        ChallengeData(
            id: "top100",
            emoji: "📈",
            title: "Top 100 Climber",
            subtitle: "Reach the top 100 on the global leaderboard",
            description: "Grind your way to the top. Improve your overall SMV score to break into the top 100 users on the global leaderboard. Every scan counts — aim for consistency.",
            reward: "👑 Elite Badge",
            progress: 0.0,
            accentColor: .smvViolet,
            startDate: "",
            participants: 2341,
            rules: ["Must achieve top 100 rank", "Rank is based on highest overall score", "Badge awarded permanently"]
        ),
    ]

    static let upcoming: [ChallengeData] = [
        ChallengeData(
            id: "symmetry",
            emoji: "⚖️",
            title: "Symmetry Showdown",
            subtitle: "Who has the most symmetrical face?",
            description: "A week-long competition focused purely on bilateral symmetry. Your highest symmetry sub-score during the challenge period wins.",
            reward: "🥇 Symmetry Crown",
            progress: 0,
            accentColor: .smvCyan,
            startDate: "June 3",
            participants: 0,
            rules: ["Highest symmetry sub-score wins", "Minimum 3 scans during challenge week", "3D verified scans get a bonus"]
        ),
        ChallengeData(
            id: "jawline",
            emoji: "🦴",
            title: "Jaw is Law",
            subtitle: "Best jawline score wins",
            description: "Mewing devotees, this one's for you. Compete for the highest jawline sub-score during the challenge week.",
            reward: "💪 Jaw Badge",
            progress: 0,
            accentColor: .smvPink,
            startDate: "June 10",
            participants: 0,
            rules: ["Highest jawline sub-score wins", "Must use 3D scan if available", "Minimum 3 scans required"]
        ),
    ]
}
