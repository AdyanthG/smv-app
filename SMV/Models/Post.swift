//
//  Post.swift
//  SMV
//
//  Social feed post model persisted with SwiftData.
//

import Foundation
import SwiftData

@Model
final class Post {

    @Attribute(.unique)
    var id: String

    var authorId: String
    var authorName: String
    var authorHandle: String
    var authorAvatarURL: String?
    var authorScore: Double?
    var imageURL: String?
    var caption: String
    var hashtags: [String]
    var likeCount: Int
    var commentCount: Int
    var isLiked: Bool
    var isSaved: Bool
    var createdAt: Date
    var scanResultId: String?
    var scoreChange: Double?
    var isPublic: Bool

    init(
        id: String = UUID().uuidString,
        authorId: String,
        authorName: String,
        authorHandle: String,
        authorAvatarURL: String? = nil,
        authorScore: Double? = nil,
        imageURL: String? = nil,
        caption: String = "",
        hashtags: [String] = [],
        likeCount: Int = 0,
        commentCount: Int = 0,
        isLiked: Bool = false,
        isSaved: Bool = false,
        createdAt: Date = .now,
        scanResultId: String? = nil,
        scoreChange: Double? = nil,
        isPublic: Bool = true
    ) {
        self.id = id
        self.authorId = authorId
        self.authorName = authorName
        self.authorHandle = authorHandle
        self.authorAvatarURL = authorAvatarURL
        self.authorScore = authorScore
        self.imageURL = imageURL
        self.caption = caption
        self.hashtags = hashtags
        self.likeCount = likeCount
        self.commentCount = commentCount
        self.isLiked = isLiked
        self.isSaved = isSaved
        self.createdAt = createdAt
        self.scanResultId = scanResultId
        self.scoreChange = scoreChange
        self.isPublic = isPublic
    }
}
