//
//  PostDetailView.swift
//  SMV
//
//  Detailed view for a single post with comments and engagement.
//

import SwiftUI

struct PostDetailView: View {

    let postId: String

    @Environment(Router.self) private var router
    @Environment(AuthService.self) private var auth
    @Environment(FirestoreService.self) private var firestore
    @Environment(HapticService.self) private var haptics

    @State private var commentText = ""
    @State private var isLiked = false
    @State private var likeCount = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SMVSpacing.lg) {
                // Post content placeholder (would be fetched from Firestore)
                VStack(alignment: .leading, spacing: SMVSpacing.md) {
                    HStack(spacing: SMVSpacing.md) {
                        AvatarView(name: "User", size: 44)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("SMV User")
                                .font(SMVFont.title())
                                .foregroundStyle(.white)
                            Text("Just now")
                                .font(SMVFont.micro())
                                .foregroundStyle(Color.smvTextTertiary)
                        }

                        Spacer()
                    }

                    Text("Score reveal! What do you think? 👀")
                        .font(SMVFont.body())
                        .foregroundStyle(Color.smvTextPrimary)
                }
                .padding(SMVSpacing.lg)

                // Engagement bar
                HStack(spacing: SMVSpacing.xxl) {
                    Button {
                        isLiked.toggle()
                        likeCount += isLiked ? 1 : -1
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

                    HStack(spacing: SMVSpacing.xs) {
                        Image(systemName: "bubble.left")
                            .foregroundStyle(Color.smvTextSecondary)
                        Text("0")
                            .font(SMVFont.caption())
                            .foregroundStyle(Color.smvTextSecondary)
                    }

                    Spacer()

                    Button {
                        // Share
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(Color.smvTextSecondary)
                    }
                }
                .padding(.horizontal, SMVSpacing.lg)

                Divider()
                    .overlay(Color.smvSurface2)

                // Comment input
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
                        // Post comment
                        commentText = ""
                        haptics.lightImpact()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(
                                commentText.isEmpty
                                    ? Color.smvTextTertiary
                                    : Color.smvCyan
                            )
                    }
                    .disabled(commentText.isEmpty)
                }
                .padding(.horizontal, SMVSpacing.lg)

                // Empty comments state
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
            }
            .padding(.bottom, 100)
        }
        .background(Color.smvBackground)
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
