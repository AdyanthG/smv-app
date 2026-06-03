//
//  FeedView.swift
//  SMV
//
//  Social feed with Firestore-backed posts, pull-to-refresh, and empty states.
//

import SwiftUI
import SwiftData
import FirebaseFirestore

struct FeedView: View {

    @State private var selectedTab: FeedTab = .trending
    @State private var posts: [Post] = []
    @State private var isLoading = false
    @State private var blockedIds: Set<String> = []
    @State private var moderationMessage: String?
    @State private var sharePost: Post?
    @Environment(Router.self) private var router
    @Environment(FirestoreService.self) private var firestore
    @Environment(AuthService.self) private var auth
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(spacing: 0) {
            // Custom header
            HStack {
                Text("Feed")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    router.present(.createPost)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.smvCyan)
                }
            }
            .padding(.horizontal, SMVSpacing.lg)
            .padding(.top, SMVSpacing.sm)
            .padding(.bottom, SMVSpacing.xs)

            feedTabBar

            if isLoading && posts.isEmpty {
                Spacer()
                ProgressView()
                    .tint(Color.smvCyan)
                Spacer()
            } else if posts.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(posts) { post in
                            Button {
                                router.push(.postDetail(postId: post.id))
                            } label: {
                                PostCardView(
                                    post: post,
                                    onLike: { toggleLike(post) },
                                    onSave: { toggleSave(post) },
                                    onReport: { reportPost(post) },
                                    onBlock: { blockAuthor(post) },
                                    onShare: { sharePost = post }
                                )
                            }
                            .buttonStyle(.plain)
                            .task { await seedEngagement(post) }

                            Divider()
                                .overlay(Color.smvSurface2)
                        }
                    }
                    .padding(.bottom, 100)
                }
                .refreshable {
                    await loadPosts()
                }
            }
        }
        .background(Color.smvBackground)
        .navigationBarHidden(true)
        .task {
            if posts.isEmpty {
                await loadPosts()
            }
        }
        .onChange(of: selectedTab) {
            Task { await loadPosts() }
        }
        .onChange(of: router.feedRefreshToken) {
            Task { await loadPosts() }
        }
        .sheet(item: $sharePost) { post in
            let caption = post.caption.isEmpty ? "Check out their scan on SMV." : post.caption
            ShareSheet(items: ["\(post.authorName) on SMV: \(caption)"])
                .presentationDetents([.medium])
        }
        .alert("Thanks for the report", isPresented: Binding(
            get: { moderationMessage != nil },
            set: { if !$0 { moderationMessage = nil } }
        )) {
            Button("OK", role: .cancel) { moderationMessage = nil }
        } message: {
            Text(moderationMessage ?? "")
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: SMVSpacing.lg) {
            Spacer()

            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 48))
                .foregroundStyle(Color.smvTextTertiary)

            Text("No Posts Yet")
                .font(SMVFont.headline())
                .foregroundStyle(.white)

            Text("Be the first to share your journey.\nTap + to create a post.")
                .font(SMVFont.body())
                .foregroundStyle(Color.smvTextSecondary)
                .multilineTextAlignment(.center)

            Button {
                router.present(.createPost)
            } label: {
                HStack(spacing: SMVSpacing.sm) {
                    Image(systemName: "plus")
                    Text("Create Post")
                }
                .font(SMVFont.title())
                .foregroundStyle(.white)
                .padding(.horizontal, SMVSpacing.xxl)
                .padding(.vertical, SMVSpacing.md)
                .background(
                    Capsule()
                        .fill(LinearGradient.brandPrimary)
                )
            }

            Spacer()
        }
        .padding(.horizontal, SMVSpacing.xxl)
    }

    // MARK: - Tab Bar

    private var feedTabBar: some View {
        HStack(spacing: 0) {
            ForEach(FeedTab.allCases) { tab in
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text(tab.rawValue)
                            .font(SMVFont.caption())
                            .foregroundStyle(selectedTab == tab ? .white : .smvTextTertiary)

                        Rectangle()
                            .fill(selectedTab == tab ? Color.smvCyan : .clear)
                            .frame(height: 2)
                            .clipShape(Capsule())
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, SMVSpacing.lg)
    }

    // MARK: - Data Loading

    private func loadPosts() async {
        isLoading = true

        // Refresh the blocked set so blocked users never appear in the feed.
        if let userId = auth.currentUserId {
            blockedIds = await firestore.fetchBlockedIds(userId: userId)
        }

        // Fetch a generous window so Trending/Following can filter/reorder client-side.
        let firestorePosts = await firestore.fetchFeedPosts(limit: 60)

        var mapped: [Post] = firestorePosts.compactMap { data in
            guard let authorId = data["authorId"] as? String,
                  let authorName = data["authorName"] as? String,
                  let authorHandle = data["authorHandle"] as? String else {
                return nil
            }
            return Post(
                id: data["id"] as? String ?? UUID().uuidString,
                authorId: authorId,
                authorName: authorName,
                authorHandle: authorHandle,
                authorAvatarURL: data["authorAvatarURL"] as? String,
                authorScore: data["authorScore"] as? Double,
                imageURL: data["imageURL"] as? String,
                caption: data["caption"] as? String ?? "",
                hashtags: data["hashtags"] as? [String] ?? [],
                likeCount: data["likeCount"] as? Int ?? 0,
                commentCount: data["commentCount"] as? Int ?? 0,
                createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? .now,
                scanResultId: data["scanResultId"] as? String,
                scoreChange: data["scoreChange"] as? Double,
                isPublic: data["isPublic"] as? Bool ?? true
            )
        }

        // Never show posts from blocked authors.
        mapped = mapped.filter { !blockedIds.contains($0.authorId) }

        // Tab-specific filtering / ordering.
        switch selectedTab {
        case .new:
            mapped.sort { $0.createdAt > $1.createdAt }
        case .trending:
            // Most engagement first (likes, then comments).
            mapped.sort { ($0.likeCount, $0.commentCount) > ($1.likeCount, $1.commentCount) }
        case .following:
            if let userId = auth.currentUserId {
                let followingIds = Set(await firestore.fetchFollowingIds(userId: userId))
                mapped = mapped.filter { followingIds.contains($0.authorId) }
            } else {
                mapped = []
            }
            mapped.sort { $0.createdAt > $1.createdAt }
        }

        posts = Array(mapped.prefix(30))
        isLoading = false
    }

    // MARK: - Engagement

    /// Seed like/save state for a post from Firestore when its card appears.
    private func seedEngagement(_ post: Post) async {
        guard let userId = auth.currentUserId else { return }
        let liked = await firestore.isPostLiked(postId: post.id, userId: userId)
        let saved = await firestore.isPostSaved(postId: post.id, userId: userId)
        post.isLiked = liked
        post.isSaved = saved
    }

    private func toggleLike(_ post: Post) {
        guard let userId = auth.currentUserId else { return }
        post.isLiked.toggle()
        post.likeCount += post.isLiked ? 1 : -1
        Task { await firestore.toggleLike(postId: post.id, userId: userId) }
    }

    private func toggleSave(_ post: Post) {
        guard let userId = auth.currentUserId else { return }
        post.isSaved.toggle()
        Task { await firestore.toggleSave(postId: post.id, userId: userId) }
    }

    // MARK: - Moderation

    private func reportPost(_ post: Post) {
        guard let userId = auth.currentUserId else { return }
        // Optimistically hide the reported post.
        posts.removeAll { $0.id == post.id }
        moderationMessage = "We'll review this post and take action if it violates our guidelines."
        Task {
            await firestore.reportPost(
                postId: post.id,
                authorId: post.authorId,
                reporterId: userId,
                reason: "user_report"
            )
        }
    }

    private func blockAuthor(_ post: Post) {
        guard let userId = auth.currentUserId else { return }
        blockedIds.insert(post.authorId)
        // Remove everything from this author immediately.
        posts.removeAll { $0.authorId == post.authorId }
        moderationMessage = "You won't see posts from \(post.authorName) anymore."
        Task { await firestore.blockUser(userId: userId, blockedId: post.authorId) }
    }
}

enum FeedTab: String, CaseIterable, Identifiable {
    case trending = "Trending"
    case following = "Following"
    case new = "New"
    var id: String { rawValue }
}

#Preview {
    NavigationStack { FeedView() }
        .environment(Router())
        .environment(FirestoreService())
        .modelContainer(for: Post.self, inMemory: true)
}
