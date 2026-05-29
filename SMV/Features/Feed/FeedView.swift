//
//  FeedView.swift
//  SMV
//
//  Social feed with Firestore-backed posts, pull-to-refresh, and empty states.
//

import SwiftUI
import SwiftData

struct FeedView: View {

    @State private var selectedTab: FeedTab = .trending
    @State private var posts: [Post] = []
    @State private var isLoading = false
    @Environment(Router.self) private var router
    @Environment(FirestoreService.self) private var firestore
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
                                PostCardView(post: post)
                            }
                            .buttonStyle(.plain)

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

        // Fetch from Firestore
        let firestorePosts = await firestore.fetchFeedPosts(limit: 30)

        if !firestorePosts.isEmpty {
            // Convert Firestore documents to Post objects
            posts = firestorePosts.compactMap { data in
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
                    authorScore: data["authorScore"] as? Double,
                    caption: data["caption"] as? String ?? "",
                    hashtags: data["hashtags"] as? [String] ?? [],
                    likeCount: data["likeCount"] as? Int ?? 0,
                    commentCount: data["commentCount"] as? Int ?? 0
                )
            }
        }
        // If Firestore is empty, posts stays empty → shows empty state

        isLoading = false
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
