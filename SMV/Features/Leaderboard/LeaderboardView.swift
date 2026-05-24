//
//  LeaderboardView.swift
//  SMV
//
//  Daily-first leaderboard with per-metric boards and tappable profiles.
//

import SwiftUI

struct LeaderboardView: View {

    @State private var selectedCategory: LeaderboardCategory = .global
    @State private var selectedTimeframe: Timeframe = .today
    @Environment(Router.self) private var router

    var body: some View {
        ScrollView {
            VStack(spacing: SMVSpacing.xl) {
                timeframeToggle
                categoryFilter
                podiumSection
                rankList
            }
            .padding(.bottom, 100)
        }
        .background(Color.smvBackground)
        .navigationTitle("Ranks")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Timeframe Toggle

    private var timeframeToggle: some View {
        HStack(spacing: 0) {
            ForEach(Timeframe.allCases) { tf in
                Button {
                    withAnimation(.spring(duration: 0.3)) { selectedTimeframe = tf }
                } label: {
                    Text(tf.rawValue)
                        .font(SMVFont.caption())
                        .foregroundStyle(selectedTimeframe == tf ? .white : Color.smvTextTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SMVSpacing.sm)
                        .background(
                            selectedTimeframe == tf
                                ? Capsule().fill(Color.smvSurface2)
                                : Capsule().fill(.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.smvSurface0))
        .padding(.horizontal, SMVSpacing.lg)
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SMVSpacing.sm) {
                ForEach(LeaderboardCategory.allCases, id: \.self) { cat in
                    Button {
                        withAnimation(.spring(duration: 0.3)) { selectedCategory = cat }
                    } label: {
                        Text(cat.rawValue)
                            .font(SMVFont.caption())
                            .foregroundStyle(selectedCategory == cat ? .white : Color.smvTextTertiary)
                            .padding(.horizontal, SMVSpacing.lg)
                            .padding(.vertical, SMVSpacing.sm)
                            .background(
                                Capsule().fill(selectedCategory == cat ? Color.smvViolet : Color.smvSurface1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, SMVSpacing.lg)
        }
    }

    // MARK: - Podium

    private var podiumSection: some View {
        HStack(alignment: .bottom, spacing: SMVSpacing.md) {
            podiumCard(rank: 2, entry: mockDaily[1], height: 90)
            podiumCard(rank: 1, entry: mockDaily[0], height: 120)
            podiumCard(rank: 3, entry: mockDaily[2], height: 72)
        }
        .padding(.horizontal, SMVSpacing.lg)
    }

    private func podiumCard(rank: Int, entry: DailyRankEntry, height: CGFloat) -> some View {
        VStack(spacing: SMVSpacing.sm) {
            if rank == 1 {
                Image(systemName: "crown.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.smvAmber)
            }

            // Tappable avatar
            Button {
                router.push(.userProfile(userId: entry.userId))
            } label: {
                AvatarView(name: entry.name, score: entry.score, size: rank == 1 ? 56 : 44)
            }
            .buttonStyle(.plain)

            Text(entry.name)
                .font(SMVFont.micro())
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(entry.score.scoreFormatted)
                .font(SMVFont.title())
                .foregroundStyle(.white)

            // Podium block
            RoundedRectangle(cornerRadius: SMVRadius.sm)
                .fill(rank == 1 ? Color.smvAmber.opacity(0.15) : Color.smvSurface1)
                .frame(height: height)
                .overlay(
                    VStack(spacing: 2) {
                        Text("#\(rank)")
                            .font(SMVFont.headline())
                            .foregroundStyle(rank == 1 ? Color.smvAmber : Color.smvTextSecondary)
                        if let change = entry.rankChange {
                            RankChangeLabel(change: change)
                        }
                    }
                )
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Rank List

    private var rankList: some View {
        VStack(spacing: SMVSpacing.sm) {
            ForEach(Array(mockDaily.dropFirst(3).enumerated()), id: \.element.id) { index, entry in
                rankRow(entry, rank: index + 4)
            }
        }
        .padding(.horizontal, SMVSpacing.lg)
    }

    private func rankRow(_ entry: DailyRankEntry, rank: Int) -> some View {
        Button {
            router.push(.userProfile(userId: entry.userId))
        } label: {
            HStack(spacing: SMVSpacing.md) {
                Text("#\(rank)")
                    .font(SMVFont.title())
                    .fontDesign(.rounded)
                    .foregroundStyle(Color.smvTextTertiary)
                    .frame(width: 32, alignment: .leading)

                AvatarView(name: entry.name, score: entry.score, size: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name)
                        .font(SMVFont.title())
                        .foregroundStyle(.white)
                    Text("Today · \(entry.scans) scans")
                        .font(SMVFont.micro())
                        .foregroundStyle(Color.smvTextTertiary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(entry.score.scoreFormatted)
                        .font(SMVFont.headline())
                        .foregroundStyle(.white)
                    if let change = entry.rankChange {
                        RankChangeLabel(change: change)
                    }
                }
            }
            .padding(SMVSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: SMVRadius.md)
                    .fill(Color.smvSurface0)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Rank Change Label

private struct RankChangeLabel: View {
    let change: Int

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: change > 0 ? "arrow.up" : change < 0 ? "arrow.down" : "minus")
                .font(.system(size: 9, weight: .bold))
            Text("\(abs(change))")
                .font(SMVFont.micro())
        }
        .foregroundStyle(change > 0 ? Color.smvEmerald : change < 0 ? Color.smvPink : Color.smvTextTertiary)
    }
}

// MARK: - Timeframe

enum Timeframe: String, CaseIterable, Identifiable {
    case today = "Today"
    case week = "This Week"
    case allTime = "All Time"
    var id: String { rawValue }
}

// MARK: - Mock Data

private struct DailyRankEntry: Identifiable {
    let id = UUID()
    let userId: String
    let name: String
    let score: Double
    let scans: Int
    let rankChange: Int?
}

private let mockDaily: [DailyRankEntry] = [
    DailyRankEntry(userId: "1", name: "Marcus W", score: 9.5, scans: 3, rankChange: nil),
    DailyRankEntry(userId: "2", name: "Jordan K", score: 9.1, scans: 2, rankChange: 2),
    DailyRankEntry(userId: "3", name: "Alex C",   score: 8.9, scans: 1, rankChange: -1),
    DailyRankEntry(userId: "4", name: "Riley M",  score: 8.7, scans: 4, rankChange: 3),
    DailyRankEntry(userId: "5", name: "Casey L",  score: 8.5, scans: 2, rankChange: -2),
    DailyRankEntry(userId: "6", name: "Drew N",   score: 8.4, scans: 5, rankChange: 1),
    DailyRankEntry(userId: "7", name: "Sam T",    score: 8.2, scans: 1, rankChange: nil),
    DailyRankEntry(userId: "8", name: "Chris P",  score: 8.1, scans: 3, rankChange: -1),
    DailyRankEntry(userId: "9", name: "Blake R",  score: 8.0, scans: 2, rankChange: 4),
    DailyRankEntry(userId: "10", name: "Taylor V", score: 7.9, scans: 1, rankChange: -3),
]

#Preview {
    NavigationStack { LeaderboardView() }
        .environment(Router())
}
