//
//  UserProfileView.swift
//  SMV
//
//  Public profile — fetches real data from Firestore.
//

import SwiftUI

struct UserProfileView: View {

    let userId: String
    var displayName: String = ""
    var score: Double = 0
    var handle: String = ""

    @Environment(Router.self) private var router
    @Environment(FirestoreService.self) private var firestore
    @State private var profileName: String = ""
    @State private var profileHandle: String = ""
    @State private var profileScore: Double = 0
    @State private var profileBio: String = ""
    @State private var scanCount: Int = 0
    @State private var bestScore: Double = 0
    @State private var streak: Int = 0
    @State private var isLoaded = false

    private var tier: ScoreTier { ScoreTier.from(score: profileScore) }

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
                        Text(profileName.prefix(1).uppercased())
                            .font(SMVFont.displaySmall())
                            .foregroundStyle(tier.color)
                    }

                    VStack(spacing: SMVSpacing.xs) {
                        Text(profileName)
                            .font(SMVFont.headline())
                            .foregroundStyle(.white)
                        if !profileHandle.isEmpty {
                            Text("@\(profileHandle)")
                                .font(SMVFont.caption())
                                .foregroundStyle(Color.smvTextTertiary)
                        }
                    }

                    // Bio
                    if !profileBio.isEmpty {
                        Text(profileBio)
                            .font(SMVFont.body())
                            .foregroundStyle(Color.smvTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, SMVSpacing.xxl)
                    }

                    // Score
                    if profileScore > 0 {
                        VStack(spacing: SMVSpacing.xs) {
                            Text(profileScore.scoreFormatted)
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
                }
                .padding(.top, SMVSpacing.xxl)

                // Stats
                HStack(spacing: 0) {
                    statItem(value: "\(scanCount)", label: "Scans")
                    Divider()
                        .frame(height: 32)
                        .overlay(Color.smvSurface2)
                    statItem(value: bestScore > 0 ? String(format: "%.1f", bestScore) : "—", label: "Best")
                    Divider()
                        .frame(height: 32)
                        .overlay(Color.smvSurface2)
                    statItem(value: tier.rarity, label: "Rarity")
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

                    if scanCount == 0 {
                        VStack(spacing: SMVSpacing.md) {
                            Image(systemName: "viewfinder")
                                .font(.system(size: 32))
                                .foregroundStyle(Color.smvTextTertiary)
                            Text("No scans yet")
                                .font(SMVFont.caption())
                                .foregroundStyle(Color.smvTextSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SMVSpacing.xxl)
                    } else {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: SMVSpacing.sm),
                            GridItem(.flexible(), spacing: SMVSpacing.sm),
                            GridItem(.flexible(), spacing: SMVSpacing.sm),
                        ], spacing: SMVSpacing.sm) {
                            ForEach(0..<min(scanCount, 6), id: \.self) { _ in
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
                }
                .padding(.horizontal, SMVSpacing.xxl)
            }
        }
        .background(Color.smvBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            if !isLoaded {
                // Use passed values as defaults
                profileName = displayName.isEmpty ? "User" : displayName
                profileScore = score
                profileHandle = handle

                // Fetch real data from Firestore
                if let data = await firestore.fetchUserProfile(userId: userId) {
                    profileName = data["displayName"] as? String ?? profileName
                    profileHandle = data["handle"] as? String ?? profileHandle
                    profileBio = data["bio"] as? String ?? ""
                    profileScore = data["latestScore"] as? Double ?? profileScore
                    bestScore = data["bestScore"] as? Double ?? profileScore
                    scanCount = data["scanCount"] as? Int ?? 0
                }

                let stats = await firestore.fetchUserStats(userId: userId)
                if stats.scanCount > 0 {
                    scanCount = stats.scanCount
                    bestScore = stats.bestScore
                    streak = stats.streak
                }

                isLoaded = true
            }
        }
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
