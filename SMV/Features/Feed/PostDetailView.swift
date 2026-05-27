//
//  PostDetailView.swift
//  SMV
//
//  Full post view with real data, comments, likes, and comment input.
//

import SwiftUI
import SwiftData

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

    private var post: Post? {
        allPosts.first { $0.id == postId }
    }

    private var comments: [Comment] {
        allComments
            .filter { $0.postId == postId }
            .sorted { $0.createdAt < $1.createdAt }
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
        .onAppear {
            if let post {
                isLiked = post.isLiked
                likeCount = post.likeCount
            }
        }
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
                // TODO: Share sheet
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .foregroundStyle(Color.smvTextSecondary)
            }
        }
        .padding(.horizontal, SMVSpacing.lg)
        .padding(.vertical, SMVSpacing.md)
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

        let comment = Comment(
            postId: postId,
            authorId: auth.currentUserId ?? "guest",
            authorName: auth.displayName.isEmpty ? "You" : auth.displayName,
            authorHandle: UserDefaults.standard.string(forKey: "smv_handle") ?? "user",
            body: commentText
        )
        modelContext.insert(comment)

        // Update post comment count
        if let post {
            post.commentCount += 1
        }

        // Also save to Firestore
        Task {
            await firestore.saveComment(
                postId: postId,
                authorId: auth.currentUserId ?? "guest",
                authorName: auth.displayName.isEmpty ? "You" : auth.displayName,
                body: commentText
            )
        }

        commentText = ""
    }
}
