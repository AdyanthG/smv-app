//
//  FeedView.swift
//  SMV
//
//  Social feed with trending/following/new tabs and mock data.
//

import SwiftUI
import SwiftData

struct FeedView: View {

    @State private var selectedTab: FeedTab = .trending
    @State private var posts: [Post] = []
    @Environment(Router.self) private var router

    var body: some View {
        VStack(spacing: 0) {
            feedTabBar

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(posts) { post in
                        Button {
                            router.push(.postDetail(postId: post.id))
                        } label: {
                            PostCardView(post: post)
                        }
                        .buttonStyle(.plain)

                        Divider()
                            .overlay(Color.smvSurface2)
                    }
                }
                .padding(.bottom, 100)
            }
        }
        .background(Color.smvBackground)
        .navigationTitle("Feed")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                // Easter egg: ".org" → hidden forum entry
                Button {
                    router.push(.community)
                } label: {
                    Text(".org")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.smvTextTertiary.opacity(0.5))
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.present(.createPost)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.smvCyan)
                }
            }
        }
        .onAppear {
            if posts.isEmpty { loadMockPosts() }
        }
    }

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

    private func loadMockPosts() {
        posts = [
            Post(authorId: "1", authorName: "Alex Chen", authorHandle: "alexmaxx",
                 authorScore: 8.7, imageURL: "placeholder",
                 caption: "3 months of mewing + skincare routine. The jawline is coming in 🔥",
                 hashtags: ["jawline", "softmaxxing", "progress"],
                 likeCount: 342, commentCount: 56,
                 createdAt: Date.now.addingTimeInterval(-3600), scoreChange: 0.4),
            Post(authorId: "2", authorName: "Jordan K", authorHandle: "jk_ascend",
                 authorScore: 7.9, imageURL: "placeholder",
                 caption: "New scan after starting retinol. Skin clarity went up significantly 📈",
                 hashtags: ["skincare", "retinol", "glowup"],
                 likeCount: 218, commentCount: 34,
                 createdAt: Date.now.addingTimeInterval(-7200), scoreChange: 0.3),
            Post(authorId: "3", authorName: "Marcus W", authorHandle: "psl_king",
                 authorScore: 9.1, imageURL: "placeholder",
                 caption: "Hit diamond tier today. It's been a journey. AMA in the comments 💎",
                 hashtags: ["elite", "diamondtier", "looksmaxxing"],
                 likeCount: 891, commentCount: 127, isLiked: true,
                 createdAt: Date.now.addingTimeInterval(-14400)),
            Post(authorId: "4", authorName: "Riley M", authorHandle: "riley_glow",
                 authorScore: 6.8,
                 caption: "Day 1 of taking this seriously. Posting for accountability. Let's go 💪",
                 hashtags: ["day1", "accountability", "softmaxxing"],
                 likeCount: 156, commentCount: 89,
                 createdAt: Date.now.addingTimeInterval(-28800)),
        ]
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
        .modelContainer(for: Post.self, inMemory: true)
}
