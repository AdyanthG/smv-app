//
//  PostDetailView.swift
//  SMV
//
//  Full post view with real data, comments, likes, and comment input.
//

import SwiftUI
import SwiftData
import FirebaseFirestore

struct PostDetailView: View {

    let postId: String

    @Environment(Router.self) private var router
    @Environment(AuthService.self) private var auth
    @Environment(FirestoreService.self) private var firestore
    @Environment(HapticService.self) private var haptics
    @Environment(\.modelContext) private var modelContext

    @Query private var allPosts: [Post]
    @Query private var allComments: [Comment]

    @State private var commentText = ""
    @State private var isLiked = false
    @State private var likeCount = 0
    @State private var remotePost: Post?
    @State private var remoteComments: [Comment] = []
    @State private var showShareSheet = false

    private var post: Post? {
        allPosts.first { $0.id == postId } ?? remotePost
    }

    private var comments: [Comment] {
        let local = allComments.filter { $0.postId == postId }
        // Merge remote + local, with local taking precedence on id collisions.
        var byId: [String: Comment] = [:]
        for comment in remoteComments + local {
            byId[comment.id] = comment
        }
        return byId.values.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let post {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Post content
                        postContent(post)

                        Divider().overlay(Color.smvSurface2)

                        // Engagement bar
                        engagementBar(post)

                        Divider().overlay(Color.smvSurface2)

                        // Comments
                        if comments.isEmpty {
                            VStack(spacing: SMVSpacing.md) {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.system(size: 32))
                                    .foregroundStyle(Color.smvTextTertiary)
                                Text("No comments yet")
                                    .font(SMVFont.body())
                                    .foregroundStyle(Color.smvTextSecondary)
                                Text("Be the first to comment")
                                    .font(SMVFont.caption())
                                    .foregroundStyle(Color.smvTextTertiary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, SMVSpacing.xxxl)
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(comments) { comment in
                                    commentRow(comment)
                                    Divider().overlay(Color.smvSurface2.opacity(0.5))
                                }
                            }
                        }
                    }
                    .padding(.bottom, 80)
                }

                // Comment input bar
                commentBar
            } else {
                // No local post found — show loading / not found
                VStack(spacing: SMVSpacing.lg) {
                    Spacer()
                    ProgressView().tint(Color.smvCyan)
                    Text("Loading post...")
                        .font(SMVFont.caption())
                        .foregroundStyle(Color.smvTextTertiary)
                    Spacer()
                }
            }
        }
        .background(Color.smvBackground)
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            if let post, post.authorId != auth.currentUserId {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive) { reportPost(post) } label: {
                            Label("Report Post", systemImage: "flag")
                        }
                        Button(role: .destructive) { blockAuthor(post) } label: {
                            Label("Block \(post.authorName)", systemImage: "hand.raised")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(Color.smvTextSecondary)
                    }
                }
            }
        }
        .task {
            await loadPost()
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [shareText])
                .presentationDetents([.medium])
        }
    }

    // MARK: - Moderation

    private func reportPost(_ post: Post) {
        guard let userId = auth.currentUserId else { return }
        haptics.mediumImpact()
        Task {
            await firestore.reportPost(
                postId: post.id,
                authorId: post.authorId,
                reporterId: userId,
                reason: "user_report"
            )
        }
        router.pop()
    }

    private func blockAuthor(_ post: Post) {
        guard let userId = auth.currentUserId else { return }
        haptics.mediumImpact()
        Task { await firestore.blockUser(userId: userId, blockedId: post.authorId) }
        router.pop()
    }

    // MARK: - Loading

    private func loadPost() async {
        // Fetch the post from Firestore if it isn't in local storage.
        if post == nil, let data = await firestore.fetchPost(postId: postId) {
            remotePost = Self.makePost(from: data)
        }

        // Seed engagement counts from whichever post we resolved.
        if let post {
            likeCount = post.likeCount
            isLiked = post.isLiked
        }

        // Resolve the viewer's like state from Firestore.
        if let userId = auth.currentUserId {
            let liked = await firestore.isPostLiked(postId: postId, userId: userId)
            isLiked = liked
            post?.isLiked = liked
        }

        // Load comments from Firestore (merged with any local ones).
        let raw = await firestore.fetchComments(postId: postId)
        remoteComments = raw.compactMap { Self.makeComment(from: $0) }

        // Keep the post's comment count consistent with what we loaded.
        if let post, comments.count > post.commentCount {
            post.commentCount = comments.count
        }
    }

    private static func makePost(from data: [String: Any]) -> Post? {
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

    private static func makeComment(from data: [String: Any]) -> Comment? {
        guard let id = data["id"] as? String,
              let authorId = data["authorId"] as? String,
              let body = data["body"] as? String else {
            return nil
        }
        return Comment(
            id: id,
            postId: data["postId"] as? String ?? "",
            authorId: authorId,
            authorName: data["authorName"] as? String ?? "User",
            authorHandle: data["authorHandle"] as? String ?? "",
            body: body,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? .now
        )
    }

    // MARK: - Post Content

    private func postContent(_ post: Post) -> some View {
        VStack(alignment: .leading, spacing: SMVSpacing.md) {
            // Author row
            HStack(spacing: SMVSpacing.md) {
                Button {
                    router.push(.userProfile(userId: post.authorId))
                } label: {
                    AvatarView(name: post.authorName, score: post.authorScore, size: 44)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: SMVSpacing.sm) {
                        Text(post.authorName)
                            .font(SMVFont.title())
                            .foregroundStyle(.white)
                        if let score = post.authorScore {
                            ScoreBadge(score: score, size: .small)
                        }
                    }
                    Text("@\(post.authorHandle) · \(post.createdAt.relativeShort)")
                        .font(SMVFont.micro())
                        .foregroundStyle(Color.smvTextTertiary)
                }

                Spacer()
            }

            // Scan image — full face (no crop), tappable into the 5-angle gallery
            if let urlStr = post.imageURL, let url = URL(string: urlStr) {
                Button {
                    if let scanId = post.scanResultId {
                        router.present(.scanGallery(
                            userId: post.authorId,
                            displayName: post.authorName,
                            scanId: scanId
                        ))
                    }
                } label: {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFit()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: SMVRadius.md)
                            .fill(Color.smvSurface1)
                            .frame(height: 280)
                            .overlay(ProgressView().tint(Color.smvCyan))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 440)
                    .background(Color.smvSurface1)
                    .clipShape(RoundedRectangle(cornerRadius: SMVRadius.md))
                    .overlay(alignment: .bottomTrailing) {
                        if post.scanResultId != nil {
                            HStack(spacing: 4) {
                                Image(systemName: "square.stack.3d.up.fill").font(.system(size: 10))
                                Text("All angles").font(SMVFont.micro())
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, SMVSpacing.sm)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(.black.opacity(0.5)))
                            .padding(SMVSpacing.sm)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(post.scanResultId == nil)
            }

            // Caption
            if !post.caption.isEmpty {
                Text(post.caption)
                    .font(SMVFont.body())
                    .foregroundStyle(Color.smvTextPrimary)
                    .lineSpacing(4)
            }

            // Hashtags
            if !post.hashtags.isEmpty {
                HStack(spacing: SMVSpacing.sm) {
                    ForEach(post.hashtags.prefix(5), id: \.self) { tag in
                        Text("#\(tag)")
                            .font(SMVFont.micro())
                            .foregroundStyle(Color.smvCyan)
                    }
                }
            }

            // Score change badge
            if let change = post.scoreChange {
                HStack(spacing: SMVSpacing.xs) {
                    Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 10, weight: .bold))
                    Text(String(format: "%+.1f", change))
                        .font(SMVFont.caption())
                        .fontWeight(.bold)
                }
                .foregroundStyle(change >= 0 ? Color.smvEmerald : Color.smvPink)
                .padding(.horizontal, SMVSpacing.md)
                .padding(.vertical, SMVSpacing.xs)
                .background(
                    Capsule().fill(
                        (change >= 0 ? Color.smvEmerald : Color.smvPink).opacity(0.1)
                    )
                )
            }
        }
        .padding(SMVSpacing.lg)
    }

    // MARK: - Engagement Bar

    private func engagementBar(_ post: Post) -> some View {
        HStack(spacing: SMVSpacing.xxl) {
            // Like
            Button {
                isLiked.toggle()
                likeCount += isLiked ? 1 : -1
                post.isLiked = isLiked
                post.likeCount = likeCount
                haptics.lightImpact()

                if let userId = auth.currentUserId {
                    Task {
                        await firestore.toggleLike(postId: postId, userId: userId)
                    }
                }
            } label: {
                HStack(spacing: SMVSpacing.xs) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .foregroundStyle(isLiked ? Color.smvPink : Color.smvTextSecondary)
                    Text("\(likeCount)")
                        .font(SMVFont.caption())
                        .foregroundStyle(Color.smvTextSecondary)
                }
            }

            // Comments count
            HStack(spacing: SMVSpacing.xs) {
                Image(systemName: "bubble.left")
                    .foregroundStyle(Color.smvTextSecondary)
                Text("\(comments.count)")
                    .font(SMVFont.caption())
                    .foregroundStyle(Color.smvTextSecondary)
            }

            Spacer()

            // Share
            Button {
                haptics.lightImpact()
                showShareSheet = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .foregroundStyle(Color.smvTextSecondary)
            }
        }
        .padding(.horizontal, SMVSpacing.lg)
        .padding(.vertical, SMVSpacing.md)
    }

    private var shareText: String {
        guard let post else { return "Check out SMV — Know Your Edge." }
        let caption = post.caption.isEmpty ? "Check out their scan on SMV." : post.caption
        return "\(post.authorName) on SMV: \(caption)"
    }

    // MARK: - Comment Row

    private func commentRow(_ comment: Comment) -> some View {
        HStack(alignment: .top, spacing: SMVSpacing.md) {
            Button {
                router.push(.userProfile(userId: comment.authorId))
            } label: {
                AvatarView(name: comment.authorName, size: 32)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: SMVSpacing.xs) {
                HStack(spacing: SMVSpacing.sm) {
                    Text(comment.authorName)
                        .font(SMVFont.caption())
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Text(comment.createdAt.relativeShort)
                        .font(SMVFont.micro())
                        .foregroundStyle(Color.smvTextTertiary)
                }

                Text(comment.body)
                    .font(SMVFont.body())
                    .foregroundStyle(Color.smvTextSecondary)
                    .lineSpacing(3)

                Button {
                    comment.isLiked.toggle()
                    comment.likeCount += comment.isLiked ? 1 : -1
                    haptics.lightImpact()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: comment.isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 12))
                        Text("\(comment.likeCount)")
                            .font(SMVFont.micro())
                    }
                    .foregroundStyle(comment.isLiked ? Color.smvPink : Color.smvTextTertiary)
                }
                .padding(.top, 2)
            }
        }
        .padding(SMVSpacing.lg)
    }

    // MARK: - Comment Bar

    private var commentBar: some View {
        HStack(spacing: SMVSpacing.md) {
            TextField("Add a comment...", text: $commentText)
                .font(SMVFont.body())
                .foregroundStyle(.white)
                .padding(SMVSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: SMVRadius.md)
                        .fill(Color.smvSurface1)
                )

            Button {
                postComment()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        commentText.isEmpty ? Color.smvTextTertiary : Color.smvCyan
                    )
            }
            .disabled(commentText.isEmpty)
        }
        .padding(.horizontal, SMVSpacing.lg)
        .padding(.vertical, SMVSpacing.sm)
        .background(Color.smvSurface0)
    }

    private func postComment() {
        guard !commentText.isEmpty else { return }
        haptics.mediumImpact()

        let authorHandle = UserDefaults.standard.string(forKey: "smv_handle") ?? "user"
        let authorName = auth.displayName.isEmpty ? "You" : auth.displayName
        let authorId = auth.currentUserId ?? "guest"
        let comment = Comment(
            postId: postId,
            authorId: authorId,
            authorName: authorName,
            authorHandle: authorHandle,
            body: commentText
        )
        modelContext.insert(comment)

        // Update post comment count
        if let post {
            post.commentCount += 1
        }

        // Save to Firestore with the SAME id so it dedupes with the local copy.
        let body = commentText
        Task {
            await firestore.saveComment(
                id: comment.id,
                postId: postId,
                authorId: authorId,
                authorName: authorName,
                authorHandle: authorHandle,
                body: body
            )
        }

        commentText = ""
    }
}
