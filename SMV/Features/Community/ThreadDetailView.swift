//
//  ThreadDetailView.swift
//  SMV
//
//  Full thread view with original post, replies, and reply input.
//

import SwiftUI
import SwiftData

struct ThreadDetailView: View {

    let threadId: String

    @Environment(Router.self) private var router
    @Environment(AuthService.self) private var auth
    @Environment(HapticService.self) private var haptics
    @Environment(FirestoreService.self) private var firestore
    @Environment(\.modelContext) private var modelContext
    @Query private var allThreads: [ForumThread]
    @Query private var allReplies: [ForumReply]
    @State private var replyText = ""
    @State private var isLiked = false

    private var thread: ForumThread? {
        allThreads.first { $0.id == threadId }
    }

    private var replies: [ForumReply] {
        allReplies
            .filter { $0.threadId == threadId }
            .sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let thread {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Original post
                        originalPost(thread)

                        Divider().overlay(Color.smvSurface2)

                        // Replies
                        if replies.isEmpty {
                            VStack(spacing: SMVSpacing.md) {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.system(size: 32))
                                    .foregroundStyle(Color.smvTextTertiary)
                                Text("No replies yet")
                                    .font(SMVFont.body())
                                    .foregroundStyle(Color.smvTextSecondary)
                                Text("Be the first to reply")
                                    .font(SMVFont.caption())
                                    .foregroundStyle(Color.smvTextTertiary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, SMVSpacing.xxxl)
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(replies) { reply in
                                    replyRow(reply)
                                    Divider().overlay(Color.smvSurface2.opacity(0.5))
                                }
                            }
                        }
                    }
                    .padding(.bottom, 80)
                }

                // Reply input
                replyBar
            } else {
                Spacer()
                ProgressView().tint(Color.smvCyan)
                Spacer()
            }
        }
        .background(Color.smvBackground)
        .navigationTitle("Thread")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            if let thread {
                isLiked = thread.isLiked
                seedRepliesIfEmpty()
            }
        }
    }

    // MARK: - Original Post

    private func originalPost(_ thread: ForumThread) -> some View {
        VStack(alignment: .leading, spacing: SMVSpacing.lg) {
            // Author
            HStack(spacing: SMVSpacing.md) {
                Button {
                    router.push(.userProfile(userId: thread.authorId))
                } label: {
                    AvatarView(name: thread.authorName, score: thread.authorScore, size: 44)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: SMVSpacing.sm) {
                        Text(thread.authorName)
                            .font(SMVFont.title())
                            .foregroundStyle(.white)
                        if let score = thread.authorScore {
                            ScoreBadge(score: score, size: .small)
                        }
                    }
                    Text("@\(thread.authorHandle) · \(thread.createdAt.relativeShort)")
                        .font(SMVFont.micro())
                        .foregroundStyle(Color.smvTextTertiary)
                }

                Spacer()
            }

            // Title
            Text(thread.title)
                .font(SMVFont.headline())
                .foregroundStyle(.white)

            // Body
            if !thread.body.isEmpty {
                Text(thread.body)
                    .font(SMVFont.body())
                    .foregroundStyle(Color.smvTextSecondary)
                    .lineSpacing(4)
            }

            // Tags
            if !thread.tags.isEmpty {
                HStack(spacing: SMVSpacing.sm) {
                    ForEach(thread.tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(SMVFont.micro())
                            .foregroundStyle(Color.smvCyan)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.smvCyan.opacity(0.1)))
                    }
                }
            }

            // Engagement
            HStack(spacing: SMVSpacing.xxl) {
                Button {
                    isLiked.toggle()
                    thread.likeCount += isLiked ? 1 : -1
                    thread.isLiked = isLiked
                    haptics.lightImpact()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                        Text("\(thread.likeCount)")
                            .font(SMVFont.caption())
                    }
                    .foregroundStyle(isLiked ? Color.smvPink : Color.smvTextTertiary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "bubble.right")
                    Text("\(thread.replyCount)")
                        .font(SMVFont.caption())
                }
                .foregroundStyle(Color.smvTextTertiary)

                HStack(spacing: 4) {
                    Image(systemName: "eye")
                    Text("\(thread.viewCount)")
                        .font(SMVFont.caption())
                }
                .foregroundStyle(Color.smvTextTertiary)

                Spacer()
            }
        }
        .padding(SMVSpacing.lg)
    }

    // MARK: - Reply Row

    private func replyRow(_ reply: ForumReply) -> some View {
        HStack(alignment: .top, spacing: SMVSpacing.md) {
            Button {
                router.push(.userProfile(userId: reply.authorId))
            } label: {
                AvatarView(name: reply.authorName, score: reply.authorScore, size: 32)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: SMVSpacing.xs) {
                HStack(spacing: SMVSpacing.sm) {
                    Text(reply.authorName)
                        .font(SMVFont.caption())
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Text(reply.createdAt.relativeShort)
                        .font(SMVFont.micro())
                        .foregroundStyle(Color.smvTextTertiary)
                }

                Text(reply.body)
                    .font(SMVFont.body())
                    .foregroundStyle(Color.smvTextSecondary)
                    .lineSpacing(3)

                Button {
                    reply.isLiked.toggle()
                    reply.likeCount += reply.isLiked ? 1 : -1
                    haptics.lightImpact()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: reply.isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 12))
                        Text("\(reply.likeCount)")
                            .font(SMVFont.micro())
                    }
                    .foregroundStyle(reply.isLiked ? Color.smvPink : Color.smvTextTertiary)
                }
                .padding(.top, 2)
            }
        }
        .padding(SMVSpacing.lg)
    }

    // MARK: - Reply Bar

    private var replyBar: some View {
        HStack(spacing: SMVSpacing.md) {
            TextField("Reply...", text: $replyText)
                .font(SMVFont.body())
                .foregroundStyle(.white)
                .padding(SMVSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: SMVRadius.md)
                        .fill(Color.smvSurface1)
                )

            Button {
                postReply()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        replyText.isEmpty ? Color.smvTextTertiary : Color.smvCyan
                    )
            }
            .disabled(replyText.isEmpty)
        }
        .padding(.horizontal, SMVSpacing.lg)
        .padding(.vertical, SMVSpacing.sm)
        .background(Color.smvSurface0)
    }

    private func postReply() {
        guard !replyText.isEmpty, let thread else { return }
        haptics.mediumImpact()

        let authorId = auth.currentUserId ?? "guest"
        let authorName = auth.displayName.isEmpty ? "You" : auth.displayName
        let authorHandle = UserDefaults.standard.string(forKey: "smv_handle") ?? "user"
        let text = replyText

        let reply = ForumReply(
            threadId: threadId,
            authorId: authorId,
            authorName: authorName,
            authorHandle: authorHandle,
            body: text
        )
        modelContext.insert(reply)

        thread.replyCount += 1
        thread.lastActivityAt = .now
        replyText = ""

        // Sync to Firestore
        let replyId = reply.id
        let tid = threadId
        Task {
            await firestore.createReply(
                id: replyId,
                threadId: tid,
                authorId: authorId,
                authorName: authorName,
                authorHandle: authorHandle,
                authorScore: nil,
                body: text
            )
        }
    }

    // Seed sample replies on first view
    private func seedRepliesIfEmpty() {
        guard replies.isEmpty else { return }

        let sampleReplies: [(String, String, String)] = [
            ("Looking solid bro, keep going 💪", "reply_user_1", "Chris P"),
            ("The progress is real. What's your skincare routine?", "reply_user_2", "Sam T"),
            ("Honestly a huge improvement. Eye area is your biggest asset.", "reply_user_3", "Blake R"),
            ("How long have you been mewing?", "reply_user_4", "Taylor V"),
        ]

        for (i, (body, authorId, authorName)) in sampleReplies.enumerated() {
            let reply = ForumReply(
                threadId: threadId,
                authorId: authorId,
                authorName: authorName,
                authorHandle: authorName.lowercased().replacingOccurrences(of: " ", with: "_"),
                body: body,
                likeCount: Int.random(in: 1...50),
                createdAt: Date.now.addingTimeInterval(-Double(3600 * (sampleReplies.count - i)))
            )
            modelContext.insert(reply)
        }
    }
}
