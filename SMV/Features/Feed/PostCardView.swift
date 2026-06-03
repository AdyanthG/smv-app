//
//  PostCardView.swift
//  SMV
//
//  Reusable social feed post card.
//

import SwiftUI

struct PostCardView: View {

    let post: Post
    var onLike: (() -> Void)? = nil
    var onComment: (() -> Void)? = nil
    var onSave: (() -> Void)? = nil
    var onReport: (() -> Void)? = nil
    var onBlock: (() -> Void)? = nil
    var onShare: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Author header
            HStack(spacing: SMVSpacing.md) {
                AvatarView(
                    name: post.authorName,
                    avatarURL: post.authorAvatarURL,
                    score: post.authorScore,
                    size: 40
                )

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

                if onReport != nil || onBlock != nil {
                    Menu {
                        if let onReport {
                            Button(role: .destructive) { onReport() } label: {
                                Label("Report Post", systemImage: "flag")
                            }
                        }
                        if let onBlock {
                            Button(role: .destructive) { onBlock() } label: {
                                Label("Block \(post.authorName)", systemImage: "hand.raised")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(Color.smvTextTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(SMVSpacing.lg)

            // Image (real image when available, gradient placeholder otherwise)
            if post.imageURL != nil || post.scanResultId != nil {
                ZStack(alignment: .topTrailing) {
                    if let urlStr = post.imageURL, let url = URL(string: urlStr) {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFit()
                        } placeholder: {
                            imagePlaceholder
                        }
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: 400)
                        .background(Color.smvSurface1)
                    } else {
                        imagePlaceholder
                            .frame(height: 300)
                    }

                    // Score improvement badge
                    if let change = post.scoreChange, change != 0 {
                        HStack(spacing: 4) {
                            Image(systemName: change > 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 10, weight: .bold))
                            Text(change.deltaFormatted)
                                .font(SMVFont.caption())
                                .fontWeight(.bold)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, SMVSpacing.sm)
                        .padding(.vertical, SMVSpacing.xs)
                        .background(
                            Capsule()
                                .fill(change > 0 ? Color.smvEmerald : Color.smvPink)
                        )
                        .padding(SMVSpacing.md)
                    }
                }
            }

            // Caption
            if !post.caption.isEmpty {
                Text(post.caption)
                    .font(SMVFont.body())
                    .foregroundStyle(.white)
                    .padding(.horizontal, SMVSpacing.lg)
                    .padding(.top, SMVSpacing.md)
            }

            // Hashtags
            if !post.hashtags.isEmpty {
                Text(post.hashtags.map { "#\($0)" }.joined(separator: " "))
                    .font(SMVFont.caption())
                    .foregroundStyle(Color.smvCyan)
                    .padding(.horizontal, SMVSpacing.lg)
                    .padding(.top, SMVSpacing.xs)
            }

            // Action bar
            HStack(spacing: SMVSpacing.xxl) {
                actionButton(
                    icon: post.isLiked ? "heart.fill" : "heart",
                    count: post.likeCount,
                    color: post.isLiked ? .smvPink : .smvTextTertiary,
                    action: { onLike?() }
                )

                actionButton(
                    icon: "bubble.right",
                    count: post.commentCount,
                    color: .smvTextTertiary,
                    action: { onComment?() }
                )

                actionButton(
                    icon: "square.and.arrow.up",
                    count: 0,
                    color: .smvTextTertiary,
                    action: { onShare?() }
                )

                Spacer()

                Button { onSave?() } label: {
                    Image(systemName: post.isSaved ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(post.isSaved ? Color.smvAmber : Color.smvTextTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(SMVSpacing.lg)
        }
        .background(Color.smvSurface0)
    }

    private var imagePlaceholder: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [Color.smvSurface1, Color.smvSurface2],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(maxWidth: .infinity)
            .frame(height: 300)
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.smvTextTertiary)
            )
    }

    private func actionButton(icon: String, count: Int, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                if count > 0 {
                    Text("\(count)")
                        .font(SMVFont.micro())
                }
            }
            .foregroundStyle(color)
        }
        .buttonStyle(.plain)
    }
}
