//
//  ThreadListView.swift
//  SMV
//
//  List of threads in a forum category with create thread button.
//

import SwiftUI
import SwiftData

struct ThreadListView: View {

    let categoryTitle: String
    let categoryEmoji: String

    @Environment(Router.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Query private var allThreads: [ForumThread]

    private var threads: [ForumThread] {
        allThreads
            .filter { $0.categoryId == categoryTitle }
            .sorted { $0.lastActivityAt > $1.lastActivityAt }
    }

    var body: some View {
        Group {
            if threads.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: SMVSpacing.md) {
                        ForEach(threads) { thread in
                            Button {
                                router.push(.threadDetail(threadId: thread.id))
                            } label: {
                                threadRow(thread)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, SMVSpacing.lg)
                    .padding(.bottom, 100)
                }
            }
        }
        .background(Color.smvBackground)
        .navigationTitle("\(categoryEmoji) \(categoryTitle)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.present(.createThread(category: categoryTitle))
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.smvCyan)
                }
            }
        }
        .onAppear {
            seedIfEmpty()
        }
    }

    private var emptyState: some View {
        VStack(spacing: SMVSpacing.lg) {
            Spacer()
            Image(systemName: "text.bubble")
                .font(.system(size: 48))
                .foregroundStyle(Color.smvTextTertiary)
            Text("No Threads Yet")
                .font(SMVFont.headline())
                .foregroundStyle(.white)
            Text("Start the conversation.\nTap + to create a thread.")
                .font(SMVFont.body())
                .foregroundStyle(Color.smvTextSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }

    private func threadRow(_ thread: ForumThread) -> some View {
        GlassmorphicCard(padding: SMVSpacing.md) {
            VStack(alignment: .leading, spacing: SMVSpacing.sm) {
                if thread.isPinned {
                    HStack(spacing: 4) {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10))
                        Text("PINNED")
                            .font(SMVFont.micro())
                    }
                    .foregroundStyle(Color.smvAmber)
                }

                Text(thread.title)
                    .font(SMVFont.title())
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if !thread.body.isEmpty {
                    Text(thread.body)
                        .font(SMVFont.caption())
                        .foregroundStyle(Color.smvTextSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                HStack(spacing: SMVSpacing.lg) {
                    HStack(spacing: 4) {
                        AvatarView(name: thread.authorName, size: 18)
                        Text(thread.authorName)
                            .font(SMVFont.micro())
                            .foregroundStyle(Color.smvCyan)
                    }

                    Spacer()

                    HStack(spacing: SMVSpacing.md) {
                        HStack(spacing: 4) {
                            Image(systemName: "bubble.fill")
                                .font(.system(size: 10))
                            Text("\(thread.replyCount)")
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 10))
                            Text("\(thread.likeCount)")
                        }
                    }
                    .font(SMVFont.micro())
                    .foregroundStyle(Color.smvTextTertiary)
                }
            }
        }
    }

    // Seed sample threads for each category on first visit
    private func seedIfEmpty() {
        guard threads.isEmpty else { return }

        let samples: [(String, String, String, String)] = {
            switch categoryTitle {
            case "Rate Me":
                return [
                    ("Honest rate - 6 months into softmaxxing", "Been mewing and doing skincare for 6 months. Rate my progress honestly, no sugarcoating please.", "rate_user_1", "Alex M"),
                    ("Just got a new haircut, thoughts?", "Changed up the hairstyle completely. Does it suit my face shape? Thinking about growing it out more.", "rate_user_2", "Jordan K"),
                    ("Rate my eye area - considering cantho", "My eye area is my biggest insecurity. Is cantho worth it at this point or should I focus on other things?", "rate_user_3", "Drew T"),
                ]
            case "Softmaxxing":
                return [
                    ("My skincare routine that improved clarity by 2 pts", "Morning: CeraVe cleanser → Vitamin C serum → SPF 50. Night: Double cleanse → Tretinoin 0.025% → CeraVe moisturizer. Results after 3 months are insane.", "soft_user_1", "Riley G"),
                    ("Mewing results after 1 year — jaw transformation", "Started proper mewing technique a year ago. Jaw is significantly more defined. Posting progress pics in comments.", "soft_user_2", "Casey L"),
                    ("Best hairstyle for different face shapes?", "Can we compile a guide on which hairstyles work for each face shape? I have an oval face and can't figure out what works.", "soft_user_3", "Morgan P"),
                ]
            case "Hardmaxxing":
                return [
                    ("Rhinoplasty recovery — 3 month update", "Got rhino 3 months ago. Swelling is mostly down. Before/after scan scores showed +0.8 improvement. Worth every penny.", "hard_user_1", "Taylor R"),
                    ("Under-eye filler experiences?", "Thinking about getting tear trough filler. Anyone here done it? How long did results last?", "hard_user_2", "Sam W"),
                ]
            case "Progress Updates":
                return [
                    ("1 year transformation: 4.2 → 7.1", "Diet, exercise, skincare, mewing, better sleep. The compound effect is real. Never give up kings.", "prog_user_1", "Marcus W"),
                    ("3 month glowup — here's exactly what I did", "Dropped from 22% to 14% body fat, started retinol, got a better haircut, fixed posture. Score went from 5.1 to 6.8.", "prog_user_2", "Blake R"),
                ]
            default:
                return [
                    ("Welcome to \(categoryTitle)!", "Share your thoughts and connect with the community. Be respectful and constructive.", "mod_1", "SMV Team"),
                ]
            }
        }()

        for (title, body, authorId, authorName) in samples {
            let thread = ForumThread(
                categoryId: categoryTitle,
                authorId: authorId,
                authorName: authorName,
                authorHandle: authorName.lowercased().replacingOccurrences(of: " ", with: "_"),
                title: title,
                body: body,
                replyCount: Int.random(in: 5...120),
                viewCount: Int.random(in: 100...5000),
                likeCount: Int.random(in: 10...300),
                createdAt: Date.now.addingTimeInterval(-Double.random(in: 3600...86400*7)),
                lastActivityAt: Date.now.addingTimeInterval(-Double.random(in: 60...3600))
            )
            modelContext.insert(thread)
        }
    }
}
