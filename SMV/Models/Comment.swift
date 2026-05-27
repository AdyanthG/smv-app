//
//  Comment.swift
//  SMV
//
//  Comment model for posts and threads.
//

import Foundation
import SwiftData

@Model
final class Comment {

    @Attribute(.unique)
    var id: String

    var postId: String
    var authorId: String
    var authorName: String
    var authorHandle: String
    var body: String
    var likeCount: Int
    var isLiked: Bool
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        postId: String,
        authorId: String,
        authorName: String,
        authorHandle: String,
        body: String,
        likeCount: Int = 0,
        isLiked: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.postId = postId
        self.authorId = authorId
        self.authorName = authorName
        self.authorHandle = authorHandle
        self.body = body
        self.likeCount = likeCount
        self.isLiked = isLiked
        self.createdAt = createdAt
    }
}
