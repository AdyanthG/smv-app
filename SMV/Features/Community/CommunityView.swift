//
//  CommunityView.swift
//  SMV
//
//  Forum-style community hub inspired by looksmaxxing forums.
//

import SwiftUI

struct CommunityView: View {

    @State private var selectedSection: CommunitySection = .forum
    @State private var searchText = ""
    @Environment(Router.self) private var router

    var body: some View {
        VStack(spacing: 0) {
            // Section picker
            sectionPicker

            // Content
            switch selectedSection {
            case .forum:
                forumContent
            case .guides:
                guidesContent
            case .trending:
                trendingContent
            }
        }
        .background(Color.smvBackground)
        .navigationTitle("Community")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .searchable(text: $searchText, prompt: "Search threads...")
    }

    // MARK: - Section Picker

    private var sectionPicker: some View {
        HStack(spacing: SMVSpacing.sm) {
            ForEach(CommunitySection.allCases) { section in
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        selectedSection = section
                    }
                } label: {
                    Text(section.title)
                        .font(SMVFont.caption())
                        .foregroundStyle(selectedSection == section ? .white : .smvTextTertiary)
                        .padding(.horizontal, SMVSpacing.lg)
                        .padding(.vertical, SMVSpacing.sm)
                        .background(
                            Capsule()
                                .fill(selectedSection == section ? Color.smvViolet : Color.smvSurface2)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, SMVSpacing.lg)
        .padding(.vertical, SMVSpacing.md)
    }

    // MARK: - Forum Categories

    private var forumContent: some View {
        ScrollView {
            LazyVStack(spacing: SMVSpacing.md) {
                ForEach(ForumCategory.defaults, id: \.title) { cat in
                    categoryCard(emoji: cat.emoji, title: cat.title, description: cat.desc)
                }
            }
            .padding(.horizontal, SMVSpacing.lg)
            .padding(.bottom, 100)
        }
    }

    private func categoryCard(emoji: String, title: String, description: String) -> some View {
        Button {
            router.push(.forumCategory(title: title, emoji: emoji))
        } label: {
            GlassmorphicCard(padding: SMVSpacing.lg) {
                HStack(spacing: SMVSpacing.md) {
                    Text(emoji)
                        .font(.system(size: 28))
                        .frame(width: 44)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(SMVFont.title())
                            .foregroundStyle(.white)

                        Text(description)
                            .font(SMVFont.micro())
                            .foregroundStyle(Color.smvTextSecondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.smvTextTertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Guides

    private var guidesContent: some View {
        ScrollView {
            LazyVStack(spacing: SMVSpacing.md) {
                guideCard(
                    title: "The Complete Softmaxxing Guide",
                    author: "Top Contributor",
                    readTime: "12 min",
                    emoji: "✨",
                    likes: 2340
                )
                guideCard(
                    title: "Understanding PSL Ratings",
                    author: "Community Mod",
                    readTime: "8 min",
                    emoji: "📊",
                    likes: 1856
                )
                guideCard(
                    title: "Skincare Routine for Clarity",
                    author: "DermMax",
                    readTime: "6 min",
                    emoji: "🧴",
                    likes: 1420
                )
                guideCard(
                    title: "Jawline Enhancement: Mewing & Beyond",
                    author: "StructureKing",
                    readTime: "15 min",
                    emoji: "🦴",
                    likes: 3102
                )
                guideCard(
                    title: "Eye Area Analysis Deep Dive",
                    author: "PSL Theory",
                    readTime: "10 min",
                    emoji: "👁️",
                    likes: 1780
                )
            }
            .padding(.horizontal, SMVSpacing.lg)
            .padding(.bottom, 100)
        }
    }

    private func guideCard(title: String, author: String, readTime: String, emoji: String, likes: Int) -> some View {
        Button {
            router.push(.guideDetail(title: title, emoji: emoji, author: author, readTime: readTime))
        } label: {
            GlassmorphicCard(padding: SMVSpacing.lg) {
                VStack(alignment: .leading, spacing: SMVSpacing.md) {
                    HStack {
                        Text(emoji)
                            .font(.system(size: 24))
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.smvPink)
                            Text("\(likes)")
                                .font(SMVFont.micro())
                                .foregroundStyle(Color.smvTextSecondary)
                        }
                    }

                    Text(title)
                        .font(SMVFont.title())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: SMVSpacing.md) {
                        Text(author)
                            .font(SMVFont.micro())
                            .foregroundStyle(Color.smvCyan)
                        Text("•")
                            .foregroundStyle(Color.smvTextTertiary)
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                            Text(readTime)
                        }
                        .font(SMVFont.micro())
                        .foregroundStyle(Color.smvTextTertiary)
                    }

                    HStack {
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.smvTextTertiary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Trending

    private var trendingContent: some View {
        ScrollView {
            LazyVStack(spacing: SMVSpacing.md) {
                trendingThread(
                    title: "1 Year Softmaxxing Transformation",
                    author: "ascended_king",
                    replies: 247,
                    views: 12400,
                    tag: "Progress"
                )
                trendingThread(
                    title: "Honest rate - just got rhinoplasty",
                    author: "new_nose_who_dis",
                    replies: 189,
                    views: 8900,
                    tag: "Rate Me"
                )
                trendingThread(
                    title: "Best mewing results I've ever seen",
                    author: "structure_maxxer",
                    replies: 156,
                    views: 15600,
                    tag: "Softmaxxing"
                )
                trendingThread(
                    title: "Under eye filler worth it? PSL analysis",
                    author: "psl_theory_king",
                    replies: 134,
                    views: 7200,
                    tag: "Hardmaxxing"
                )
                trendingThread(
                    title: "My skincare routine increased clarity by 2 points",
                    author: "glow_chasher",
                    replies: 98,
                    views: 5600,
                    tag: "Guides"
                )
            }
            .padding(.horizontal, SMVSpacing.lg)
            .padding(.bottom, 100)
        }
    }

    private func trendingThread(title: String, author: String, replies: Int, views: Int, tag: String) -> some View {
        Button {
            // Navigate to the matching forum category
            router.push(.forumCategory(title: tag, emoji: "🔥"))
        } label: {
            GlassmorphicCard(padding: SMVSpacing.md) {
                VStack(alignment: .leading, spacing: SMVSpacing.sm) {
                    // Tag
                    Text(tag.uppercased())
                        .font(SMVFont.micro())
                        .foregroundStyle(Color.smvCyan)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(Color.smvCyan.opacity(0.15))
                        )

                    Text(title)
                        .font(SMVFont.title())
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: SMVSpacing.lg) {
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 10))
                            Text(author)
                        }
                        .font(SMVFont.micro())
                        .foregroundStyle(Color.smvTextSecondary)

                        Spacer()

                        HStack(spacing: SMVSpacing.md) {
                            HStack(spacing: 4) {
                                Image(systemName: "bubble.fill")
                                    .font(.system(size: 10))
                                Text("\(replies)")
                            }
                            HStack(spacing: 4) {
                                Image(systemName: "eye.fill")
                                    .font(.system(size: 10))
                                Text(views > 1000 ? "\(views / 1000)K" : "\(views)")
                            }
                        }
                        .font(SMVFont.micro())
                        .foregroundStyle(Color.smvTextTertiary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Community Section

enum CommunitySection: String, CaseIterable, Identifiable {
    case forum = "Forum"
    case guides = "Guides"
    case trending = "Trending"

    var id: String { rawValue }
    var title: String { rawValue }
}

#Preview {
    NavigationStack {
        CommunityView()
    }
    .environment(Router())
}
