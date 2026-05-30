//
//  LeaderboardView.swift
//  SMV
//
//  Firestore-backed leaderboard with real users, pull-to-refresh, and empty states.
//

import SwiftUI

struct LeaderboardView: View {

    @State private var selectedCategory: LeaderboardCategory = .global
    @State private var selectedTimeframe: Timeframe = .today
    @State private var entries: [RankEntry] = []
    @State private var isLoading = false
    @Environment(Router.self) private var router
    @Environment(FirestoreService.self) private var firestore

    var body: some View {
        VStack(spacing: 0) {
            // Custom header — inline with no clipping
            HStack {
                Text("Ranks")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(.horizontal, SMVSpacing.lg)
            .padding(.top, SMVSpacing.sm)
            .padding(.bottom, SMVSpacing.xs)

            timeframeToggle
            categoryFilter
                .padding(.top, SMVSpacing.md)

            if isLoading && entries.isEmpty {
                Spacer()
                ProgressView()
                    .tint(Color.smvCyan)
                Spacer()
            } else if entries.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: SMVSpacing.xl) {
                        if entries.count >= 3 {
                            podiumSection
                        }
                        rankList
                    }
                    .padding(.bottom, 100)
                }
                .refreshable {
                    await loadLeaderboard()
                }
            }
        }
        .background(Color.smvBackground)
        .navigationBarHidden(true)
        .task {
            if entries.isEmpty {
                await loadLeaderboard()
            }
        }
        .onChange(of: selectedTimeframe) {
            Task { await loadLeaderboard() }
        }
        .onChange(of: selectedCategory) {
            Task { await loadLeaderboard() }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: SMVSpacing.lg) {
            Spacer()

            Image(systemName: "trophy")
                .font(.system(size: 48))
                .foregroundStyle(Color.smvTextTertiary)

            Text("No Rankings Yet")
                .font(SMVFont.headline())
                .foregroundStyle(.white)

            Text("Scan your face to appear on\nthe leaderboard.")
                .font(SMVFont.body())
                .foregroundStyle(Color.smvTextSecondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
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

    // MARK: - Display helpers

    /// Score text per category — a win count for Most Voted, else a 0–10 score.
    private func scoreText(_ entry: RankEntry) -> String {
        selectedCategory.isCountMetric ? "\(Int(entry.score))" : entry.score.scoreFormatted
    }

    /// Tier ring score for the avatar — nil for count metrics so the ring stays
    /// neutral instead of implying a 0–10 tier.
    private func ringScore(_ entry: RankEntry) -> Double? {
        selectedCategory.isCountMetric ? nil : entry.score
    }

    // MARK: - Podium

    private var podiumSection: some View {
        HStack(alignment: .bottom, spacing: SMVSpacing.md) {
            podiumCard(rank: 2, entry: entries[1], height: 90)
            podiumCard(rank: 1, entry: entries[0], height: 120)
            podiumCard(rank: 3, entry: entries[2], height: 72)
        }
        .padding(.horizontal, SMVSpacing.lg)
    }

    private func podiumCard(rank: Int, entry: RankEntry, height: CGFloat) -> some View {
        VStack(spacing: SMVSpacing.sm) {
            if rank == 1 {
                Image(systemName: "crown.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.smvAmber)
            }

            // Avatar tap → scan gallery for the scan that earned this rank
            Button {
                router.present(.scanGallery(userId: entry.userId, displayName: entry.name, scanId: entry.scanId, scoreField: selectedCategory.scanField))
            } label: {
                AvatarView(name: entry.name, avatarURL: entry.avatarURL, score: ringScore(entry), size: rank == 1 ? 56 : 44)
            }
            .buttonStyle(.plain)

            // Name tap → user profile
            Button {
                router.push(.userProfile(userId: entry.userId))
            } label: {
                Text(entry.name)
                    .font(SMVFont.micro())
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .buttonStyle(.plain)

            Text(scoreText(entry))
                .font(SMVFont.title())
                .foregroundStyle(.white)

            RoundedRectangle(cornerRadius: SMVRadius.sm)
                .fill(rank == 1 ? Color.smvAmber.opacity(0.15) : Color.smvSurface1)
                .frame(height: height)
                .overlay(
                    Text("#\(rank)")
                        .font(SMVFont.headline())
                        .foregroundStyle(rank == 1 ? Color.smvAmber : Color.smvTextSecondary)
                )
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Rank List

    private var rankList: some View {
        VStack(spacing: SMVSpacing.sm) {
            let startIndex = entries.count >= 3 ? 3 : 0
            ForEach(Array(entries.dropFirst(startIndex).enumerated()), id: \.element.id) { index, entry in
                rankRow(entry, rank: index + startIndex + 1)
            }
        }
        .padding(.horizontal, SMVSpacing.lg)
    }

    private func rankRow(_ entry: RankEntry, rank: Int) -> some View {
        HStack(spacing: SMVSpacing.md) {
            Text("#\(rank)")
                .font(SMVFont.title())
                .fontDesign(.rounded)
                .foregroundStyle(Color.smvTextTertiary)
                .frame(width: 32, alignment: .leading)

            // Avatar tap → scan gallery for the scan that earned this rank
            Button {
                router.present(.scanGallery(userId: entry.userId, displayName: entry.name, scanId: entry.scanId, scoreField: selectedCategory.scanField))
            } label: {
                AvatarView(name: entry.name, avatarURL: entry.avatarURL, score: ringScore(entry), size: 40)
            }
            .buttonStyle(.plain)

            // Name tap → user profile
            Button {
                router.push(.userProfile(userId: entry.userId))
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name)
                        .font(SMVFont.title())
                        .foregroundStyle(.white)
                    Text(selectedCategory.isCountMetric ? "\(scoreText(entry)) wins" : "\(entry.scanCount) scans")
                        .font(SMVFont.micro())
                        .foregroundStyle(Color.smvTextTertiary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Text(scoreText(entry))
                .font(SMVFont.headline())
                .foregroundStyle(.white)
        }
        .padding(SMVSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: SMVRadius.md)
                .fill(Color.smvSurface0)
        )
    }

    // MARK: - Data

    private func loadLeaderboard() async {
        isLoading = true

        let data = await firestore.fetchLeaderboard(
            category: selectedCategory.rawValue,
            timeframe: selectedTimeframe.rawValue,
            limit: 50
        )

        let scoreField = selectedCategory.firestoreField

        entries = data.compactMap { item in
            guard let name = item["displayName"] as? String else { return nil }
            // Prefer the unified leaderboard score (timeframe-aware); fall back
            // to the aggregate field for older payloads.
            let score = item["leaderboardScore"] as? Double
                ?? item[scoreField] as? Double
                ?? item["bestScore"] as? Double ?? 0
            return RankEntry(
                userId: item["id"] as? String ?? "",
                name: name,
                score: score,
                scanCount: item["scanCount"] as? Int ?? 0,
                avatarURL: item["avatarURL"] as? String,
                scanId: item["scanId"] as? String
            )
        }

        isLoading = false
    }
}

// MARK: - Models

struct RankEntry: Identifiable {
    let id = UUID()
    let userId: String
    let name: String
    let score: Double
    let scanCount: Int
    let avatarURL: String?
    /// The specific scan that earned this score (timeframe leaderboards). When
    /// nil, the gallery falls back to the all-time best scan for the category.
    var scanId: String? = nil
}

// MARK: - Timeframe

enum Timeframe: String, CaseIterable, Identifiable {
    case today = "Today"
    case week = "This Week"
    case allTime = "All Time"
    var id: String { rawValue }
}

#Preview {
    NavigationStack { LeaderboardView() }
        .environment(Router())
        .environment(FirestoreService())
}
