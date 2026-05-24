//
//  ForumModels.swift
//  SMV
//
//  Community forum data models (inspired by looksmax community structure).
//

import Foundation
import SwiftData

// MARK: - Forum Category

@Model
final class ForumCategory {

    @Attribute(.unique)
    var id: String

    var title: String
    var categoryDescription: String
    var emoji: String
    var threadCount: Int
    var postCount: Int
    var sortOrder: Int

    init(
        id: String = UUID().uuidString,
        title: String,
        categoryDescription: String = "",
        emoji: String = "💬",
        threadCount: Int = 0,
        postCount: Int = 0,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.title = title
        self.categoryDescription = categoryDescription
        self.emoji = emoji
        self.threadCount = threadCount
        self.postCount = postCount
        self.sortOrder = sortOrder
    }
}

// MARK: - Forum Thread

@Model
final class ForumThread {

    @Attribute(.unique)
    var id: String

    var categoryId: String
    var authorId: String
    var authorName: String
    var authorHandle: String
    var authorAvatarURL: String?
    var authorScore: Double?
    var title: String
    var body: String
    var tags: [String]
    var replyCount: Int
    var viewCount: Int
    var likeCount: Int
    var isLiked: Bool
    var isPinned: Bool
    var isLocked: Bool
    var createdAt: Date
    var lastActivityAt: Date

    init(
        id: String = UUID().uuidString,
        categoryId: String,
        authorId: String,
        authorName: String,
        authorHandle: String,
        authorAvatarURL: String? = nil,
        authorScore: Double? = nil,
        title: String,
        body: String = "",
        tags: [String] = [],
        replyCount: Int = 0,
        viewCount: Int = 0,
        likeCount: Int = 0,
        isLiked: Bool = false,
        isPinned: Bool = false,
        isLocked: Bool = false,
        createdAt: Date = .now,
        lastActivityAt: Date = .now
    ) {
        self.id = id
        self.categoryId = categoryId
        self.authorId = authorId
        self.authorName = authorName
        self.authorHandle = authorHandle
        self.authorAvatarURL = authorAvatarURL
        self.authorScore = authorScore
        self.title = title
        self.body = body
        self.tags = tags
        self.replyCount = replyCount
        self.viewCount = viewCount
        self.likeCount = likeCount
        self.isLiked = isLiked
        self.isPinned = isPinned
        self.isLocked = isLocked
        self.createdAt = createdAt
        self.lastActivityAt = lastActivityAt
    }
}

// MARK: - Forum Reply

@Model
final class ForumReply {

    @Attribute(.unique)
    var id: String

    var threadId: String
    var authorId: String
    var authorName: String
    var authorHandle: String
    var authorAvatarURL: String?
    var authorScore: Double?
    var body: String
    var likeCount: Int
    var isLiked: Bool
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        threadId: String,
        authorId: String,
        authorName: String,
        authorHandle: String,
        authorAvatarURL: String? = nil,
        authorScore: Double? = nil,
        body: String,
        likeCount: Int = 0,
        isLiked: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.threadId = threadId
        self.authorId = authorId
        self.authorName = authorName
        self.authorHandle = authorHandle
        self.authorAvatarURL = authorAvatarURL
        self.authorScore = authorScore
        self.body = body
        self.likeCount = likeCount
        self.isLiked = isLiked
        self.createdAt = createdAt
    }
}

// MARK: - Default Categories

extension ForumCategory {
    static let defaults: [(title: String, desc: String, emoji: String)] = [
        ("Rate Me",           "Get honest community feedback on your look",        "📸"),
        ("Softmaxxing",       "Skincare, grooming, style, and fitness tips",       "✨"),
        ("Hardmaxxing",       "Cosmetic procedures, orthodontics, and surgery",    "💉"),
        ("Progress Updates",  "Share your glow up journey and transformations",    "📈"),
        ("Guides & Theory",   "PSL theory, facial analysis, and in-depth guides",  "📚"),
        ("Questions",         "Ask the community anything about looksmaxxing",     "❓"),
        ("Off-Topic",         "Lifestyle, motivation, and general discussion",     "🗣️"),
    ]
}
