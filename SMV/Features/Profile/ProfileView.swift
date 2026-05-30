//
//  ProfileView.swift
//  SMV
//
//  Simplified profile: hero score, latest scan, scan history grid.
//

import SwiftUI
import SwiftData

struct ProfileView: View {

    @Environment(Router.self) private var router
    @Environment(AuthService.self) private var auth
    @Environment(FirestoreService.self) private var firestore
    @Query(sort: \ScanResult.timestamp, order: .reverse) private var allScans: [ScanResult]
    @State private var streak: Int = 0

    /// Only the signed-in account's scans (the device can hold scans from
    /// multiple anonymous sessions).
    private var scans: [ScanResult] {
        guard let uid = auth.currentUserId else { return allScans }
        return allScans.filter { $0.userId == uid }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom header
            HStack {
                Text("Profile")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    router.push(.settings)
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.smvTextSecondary)
                }
            }
            .padding(.horizontal, SMVSpacing.lg)
            .padding(.top, SMVSpacing.sm)
            .padding(.bottom, SMVSpacing.xs)

            ScrollView {
                VStack(spacing: SMVSpacing.xxl) {
                    heroSection
                    latestScanCard
                    scanHistoryGrid
                }
                .padding(.bottom, 100)
            }
        }
        .background(Color.smvBackground)
        .navigationBarHidden(true)
        .task {
            if let userId = auth.currentUserId {
                streak = await firestore.fetchUserStreak(userId: userId)
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: SMVSpacing.lg) {
            AvatarView(
                name: auth.displayName.isEmpty ? "You" : auth.displayName,
                avatarURL: auth.avatarURL,
                score: latestScore,
                size: 80
            )

            Text(auth.displayName.isEmpty ? "SMV User" : auth.displayName)
                .font(SMVFont.headline())
                .foregroundStyle(.white)

            // Big score
            if let score = latestScore {
                VStack(spacing: SMVSpacing.xs) {
                    Text(score.scoreFormatted)
                        .font(SMVFont.displayHero())
                        .foregroundStyle(.white)

                    let tier = ScoreTier.from(score: score)
                    HStack(spacing: SMVSpacing.xs) {
                        Text(tier.emoji)
                        Text(tier.rawValue)
                            .font(SMVFont.caption())
                            .foregroundStyle(tier.color)
                    }
                }
            } else {
                VStack(spacing: SMVSpacing.sm) {
                    Text("—")
                        .font(SMVFont.displayLarge())
                        .foregroundStyle(Color.smvTextTertiary)
                    Text("No scans yet")
                        .font(SMVFont.caption())
                        .foregroundStyle(Color.smvTextTertiary)
                }
            }

            // Quick stats
            HStack(spacing: SMVSpacing.xxxl) {
                statPill(label: "Scans", value: "\(scans.count)")
                statPill(label: "Best", value: bestScore?.scoreFormatted ?? "—")
                statPill(label: "Streak", value: streak > 0 ? "\(streak)d" : "—")
            }
        }
        .padding(.top, SMVSpacing.lg)
    }

    private func statPill(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(SMVFont.title())
                .foregroundStyle(.white)
            Text(label)
                .font(SMVFont.micro())
                .foregroundStyle(Color.smvTextTertiary)
        }
    }

    // MARK: - Latest Scan Card

    private var latestScanCard: some View {
        Group {
            if let latest = scans.first {
                VStack(alignment: .leading, spacing: SMVSpacing.md) {
                    HStack {
                        Text("Latest Scan")
                            .font(SMVFont.title())
                            .foregroundStyle(.white)
                        Spacer()
                        Text(latest.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(SMVFont.micro())
                            .foregroundStyle(Color.smvTextTertiary)
                    }

                    // Attribute bars
                    VStack(spacing: SMVSpacing.sm) {
                        attributeRow("Symmetry",    latest.symmetryScore)
                        attributeRow("Jawline",     latest.jawlineScore)
                        attributeRow("Eye Area",    latest.eyeAreaScore)
                        attributeRow("Skin",        latest.skinClarityScore)
                        attributeRow("Harmony",     latest.harmonyScore)
                        attributeRow("Proportions", latest.proportionsScore)
                    }

                    // CTA
                    Button {
                        router.push(.scanResults(scanId: latest.id))
                    } label: {
                        Text("View Full Results →")
                            .font(SMVFont.caption())
                            .foregroundStyle(Color.smvCyan)
                    }
                }
                .padding(SMVSpacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: SMVRadius.lg)
                        .fill(Color.smvSurface0)
                )
                .padding(.horizontal, SMVSpacing.lg)
            } else {
                // Empty state
                VStack(spacing: SMVSpacing.md) {
                    Image(systemName: "faceid")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.smvTextTertiary)
                    Text("Take your first scan")
                        .font(SMVFont.body())
                        .foregroundStyle(Color.smvTextSecondary)

                    GradientButton(title: "Scan Now", icon: "bolt.fill", isFullWidth: false) {
                        router.switchTab(.scan)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, SMVSpacing.xxxl)
                .padding(.horizontal, SMVSpacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: SMVRadius.lg)
                        .fill(Color.smvSurface0)
                )
                .padding(.horizontal, SMVSpacing.lg)
            }
        }
    }

    private func attributeRow(_ label: String, _ score: Double) -> some View {
        HStack(spacing: SMVSpacing.sm) {
            Text(label)
                .font(SMVFont.micro())
                .foregroundStyle(Color.smvTextSecondary)
                .frame(width: 80, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.smvSurface2)
                        .frame(height: 4)

                    Capsule()
                        .fill(ScoreTier.from(score: score).color)
                        .frame(width: geo.size.width * (score / 10), height: 4)
                }
            }
            .frame(height: 4)

            Text(score.scoreFormatted)
                .font(SMVFont.micro())
                .foregroundStyle(.white)
                .frame(width: 28, alignment: .trailing)
        }
    }

    // MARK: - Scan History Grid

    private var scanHistoryGrid: some View {
        VStack(alignment: .leading, spacing: SMVSpacing.md) {
            HStack {
                Text("Scan History")
                    .font(SMVFont.title())
                    .foregroundStyle(.white)
                Spacer()
                if scans.count > 6 {
                    Button("View All") {
                        router.push(.scanHistory)
                    }
                    .font(SMVFont.micro())
                    .foregroundStyle(Color.smvCyan)
                }
            }
            .padding(.horizontal, SMVSpacing.lg)

            if scans.isEmpty {
                Text("Your scan history will appear here")
                    .font(SMVFont.caption())
                    .foregroundStyle(Color.smvTextTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, SMVSpacing.xxl)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: SMVSpacing.sm),
                    GridItem(.flexible(), spacing: SMVSpacing.sm),
                    GridItem(.flexible(), spacing: SMVSpacing.sm),
                ], spacing: SMVSpacing.sm) {
                    ForEach(scans.prefix(9)) { scan in
                        scanGridItem(scan)
                    }
                }
                .padding(.horizontal, SMVSpacing.lg)
            }
        }
    }

    private func scanGridItem(_ scan: ScanResult) -> some View {
        Button {
            router.push(.scanResults(scanId: scan.id))
        } label: {
            VStack(spacing: SMVSpacing.xs) {
                ZStack {
                    if let data = scan.imageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 110)
                            .clipShape(RoundedRectangle(cornerRadius: SMVRadius.sm))
                            .overlay(
                                // Score badge overlay at bottom-right
                                VStack {
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        Text(scan.overallScore.scoreFormatted)
                                            .font(SMVFont.caption())
                                            .fontWeight(.bold)
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(
                                                Capsule()
                                                    .fill(ScoreTier.from(score: scan.overallScore).color.opacity(0.9))
                                            )
                                            .padding(4)
                                    }
                                }
                            )
                    } else {
                        RoundedRectangle(cornerRadius: SMVRadius.sm)
                            .fill(ScoreTier.from(score: scan.overallScore).color.opacity(0.15))
                            .frame(height: 110)
                            .overlay(
                                Text(scan.overallScore.scoreFormatted)
                                    .font(SMVFont.scoreMedium())
                                    .foregroundStyle(ScoreTier.from(score: scan.overallScore).color)
                            )
                    }
                }

                Text(scan.timestamp.formatted(.dateTime.month(.abbreviated).day()))
                    .font(SMVFont.micro())
                    .foregroundStyle(Color.smvTextTertiary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var latestScore: Double? {
        scans.first?.overallScore
    }

    private var bestScore: Double? {
        scans.map(\.overallScore).max()
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
    .environment(Router())
    .environment(AuthService())
    .environment(FirestoreService())
    .modelContainer(for: ScanResult.self, inMemory: true)
}
