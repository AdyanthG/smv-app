//
//  UserProfileView.swift
//  SMV
//
//  Public profile — fetches real data from Firestore with follow system.
//

import SwiftUI
import SwiftData
import FirebaseFirestore

struct UserProfileView: View {

    let userId: String
    var displayName: String = ""
    var score: Double = 0
    var handle: String = ""

    @Environment(Router.self) private var router
    @Environment(FirestoreService.self) private var firestore
    @Environment(AuthService.self) private var auth
    @Environment(HapticService.self) private var haptics
    @Query(sort: \ScanResult.timestamp, order: .reverse) private var localScans: [ScanResult]
    @State private var profileName: String = ""
    @State private var profileHandle: String = ""
    @State private var profileScore: Double = 0
    @State private var profileBio: String = ""
    @State private var scanCount: Int = 0
    @State private var bestScore: Double = 0
    @State private var followerCount: Int = 0
    @State private var followingCount: Int = 0
    @State private var isFollowing: Bool = false
    @State private var isLoaded = false
    @State private var showShareSheet = false
    @State private var isPrivate = false
    @State private var scans: [ProfileScan] = []

    @State private var avatarURL: String?

    private var tier: ScoreTier { ScoreTier.from(score: profileScore) }
    private var isOwnProfile: Bool { userId == auth.currentUserId }

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

                        if let urlStr = avatarURL, let url = URL(string: urlStr) {
                            CachedAsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 84, height: 84)
                                    .clipShape(Circle())
                            } placeholder: {
                                Text(profileName.prefix(1).uppercased())
                                    .font(SMVFont.displaySmall())
                                    .foregroundStyle(tier.color)
                            }
                        } else {
                            Text(profileName.prefix(1).uppercased())
                                .font(SMVFont.displaySmall())
                                .foregroundStyle(tier.color)
                        }
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

                // Stats — only show after data loaded to prevent flash
                if isLoaded {
                    HStack(spacing: 0) {
                        statItem(value: "\(scanCount)", label: "Scans")
                        Divider()
                            .frame(height: 32)
                            .overlay(Color.smvSurface2)
                        statItem(value: "\(followerCount)", label: "Followers")
                        Divider()
                            .frame(height: 32)
                            .overlay(Color.smvSurface2)
                        statItem(value: "\(followingCount)", label: "Following")
                    }
                    .padding(.vertical, SMVSpacing.lg)
                    .background(Color.smvSurface0)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))

                    // Actions
                    if !isOwnProfile {
                        HStack(spacing: SMVSpacing.md) {
                            if isFollowing {
                                SecondaryButton(title: "Unfollow", icon: "person.badge.minus") {
                                    haptics.mediumImpact()
                                    Task { await toggleFollow() }
                                }
                            } else {
                                GradientButton(title: "Follow", icon: "plus") {
                                    haptics.mediumImpact()
                                    Task { await toggleFollow() }
                                }
                            }
                            SecondaryButton(title: "Share", icon: "square.and.arrow.up") {
                                showShareSheet = true
                            }
                        }
                        .padding(.horizontal, SMVSpacing.xxl)
                    }
                } else {
                    // Loading shimmer for stats
                    HStack(spacing: 0) {
                        statItem(value: "—", label: "Scans")
                        Divider()
                            .frame(height: 32)
                            .overlay(Color.smvSurface2)
                        statItem(value: "—", label: "Followers")
                        Divider()
                            .frame(height: 32)
                            .overlay(Color.smvSurface2)
                        statItem(value: "—", label: "Following")
                    }
                    .padding(.vertical, SMVSpacing.lg)
                    .background(Color.smvSurface0)
                    .redacted(reason: .placeholder)
                }

                // Recent scans
                VStack(alignment: .leading, spacing: SMVSpacing.md) {
                    Text("RECENT SCANS")
                        .font(SMVFont.micro())
                        .foregroundStyle(Color.smvTextTertiary)
                        .tracking(1)

                    if isPrivate && !isOwnProfile {
                        privateState
                    } else if isLoaded && scans.isEmpty {
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
                    } else if !scans.isEmpty {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: SMVSpacing.sm),
                            GridItem(.flexible(), spacing: SMVSpacing.sm),
                            GridItem(.flexible(), spacing: SMVSpacing.sm),
                        ], spacing: SMVSpacing.sm) {
                            ForEach(scans.prefix(9)) { scan in
                                scanThumbnail(scan)
                            }
                        }
                    } else {
                        // Loading shimmer
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: SMVSpacing.sm),
                            GridItem(.flexible(), spacing: SMVSpacing.sm),
                            GridItem(.flexible(), spacing: SMVSpacing.sm),
                        ], spacing: SMVSpacing.sm) {
                            ForEach(0..<min(max(scanCount, 3), 6), id: \.self) { _ in
                                RoundedRectangle(cornerRadius: SMVRadius.sm)
                                    .fill(Color.smvSurface1)
                                    .aspectRatio(1, contentMode: .fit)
                                    .redacted(reason: .placeholder)
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
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: ["Check out \(profileName)'s SMV profile! Score: \(profileScore.scoreFormatted)"])
                .presentationDetents([.medium])
        }
        .task {
            if !isLoaded {
                profileName = displayName.isEmpty ? "User" : displayName
                profileScore = score
                profileHandle = handle

                if let data = await firestore.fetchUserProfile(userId: userId) {
                    profileName = data["displayName"] as? String ?? profileName
                    profileHandle = data["handle"] as? String ?? profileHandle
                    profileBio = data["bio"] as? String ?? ""
                    profileScore = data["latestScore"] as? Double ?? profileScore
                    bestScore = data["bestScore"] as? Double ?? profileScore
                    scanCount = data["scanCount"] as? Int ?? 0
                    avatarURL = data["avatarURL"] as? String
                    // Default to public when the field is absent
                    isPrivate = (data["isProfilePublic"] as? Bool) == false
                }

                let stats = await firestore.fetchUserStats(userId: userId)
                if stats.scanCount > 0 {
                    scanCount = stats.scanCount
                    bestScore = stats.bestScore
                }

                // Load actual scans. For our own profile, prefer local SwiftData
                // (always has image data); otherwise fetch from Firestore.
                if isOwnProfile {
                    scans = localScans.map { ProfileScan(scan: $0) }
                    scanCount = max(scanCount, scans.count)
                } else if !isPrivate {
                    let raw = await firestore.fetchUserScans(userId: userId)
                    scans = raw.compactMap { ProfileScan(data: $0) }
                }

                // Fetch follow data
                let counts = await firestore.getFollowCounts(userId: userId)
                followerCount = counts.followers
                followingCount = counts.following

                if let myId = auth.currentUserId, myId != userId {
                    isFollowing = await firestore.isFollowing(userId: myId, targetId: userId)
                }

                isLoaded = true
            }
        }
    }

    private func toggleFollow() async {
        guard let myId = auth.currentUserId else { return }
        if isFollowing {
            await firestore.unfollowUser(userId: myId, targetId: userId)
            isFollowing = false
            followerCount = max(0, followerCount - 1)
        } else {
            await firestore.followUser(userId: myId, targetId: userId)
            isFollowing = true
            followerCount += 1
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

    // MARK: - Private State

    private var privateState: some View {
        VStack(spacing: SMVSpacing.md) {
            Image(systemName: "lock.fill")
                .font(.system(size: 32))
                .foregroundStyle(Color.smvTextTertiary)
            Text("This profile is private")
                .font(SMVFont.body())
                .foregroundStyle(Color.smvTextSecondary)
            Text("\(profileName) hasn't made their scans public.")
                .font(SMVFont.caption())
                .foregroundStyle(Color.smvTextTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SMVSpacing.xxl)
    }

    // MARK: - Scan Thumbnail

    private func scanThumbnail(_ scan: ProfileScan) -> some View {
        Button {
            router.push(.scanDetail(userId: userId, scanId: scan.id))
        } label: {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let data = scan.localImageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    } else if let urlStr = scan.frontURL, let url = URL(string: urlStr) {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            thumbnailFallback(scan.score)
                        }
                    } else {
                        thumbnailFallback(scan.score)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: SMVRadius.sm))
            .overlay(alignment: .bottomTrailing) {
                Text(scan.score.scoreFormatted)
                    .font(SMVFont.micro())
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(ScoreTier.from(score: scan.score).color.opacity(0.9)))
                    .padding(4)
            }
        }
        .buttonStyle(.plain)
    }

    private func thumbnailFallback(_ score: Double) -> some View {
        RoundedRectangle(cornerRadius: SMVRadius.sm)
            .fill(ScoreTier.from(score: score).color.opacity(0.15))
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.smvTextTertiary)
            )
    }
}

// MARK: - Profile Scan Model

struct ProfileScan: Identifiable {
    let id: String
    let score: Double
    let frontURL: String?
    let timestamp: Date
    /// Locally-stored front image (own profile) — preferred over the remote URL.
    var localImageData: Data? = nil

    /// Build from a Firestore scan document (other users).
    init?(data: [String: Any]) {
        guard let id = data["id"] as? String else { return nil }
        self.id = id
        self.score = data["overallScore"] as? Double ?? 0
        // Fall back to legacy/alternate image fields if the front URL is absent.
        self.frontURL = (data["frontImageURL"] as? String)
            ?? (data["imageURL"] as? String)
            ?? (data["leftImageURL"] as? String)
            ?? (data["rightImageURL"] as? String)
        self.timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? .distantPast
    }

    /// Build from a local SwiftData scan (own profile) — always has image data.
    init(scan: ScanResult) {
        self.id = scan.id
        self.score = scan.overallScore
        self.frontURL = nil
        self.timestamp = scan.timestamp
        self.localImageData = scan.imageData
    }
}
