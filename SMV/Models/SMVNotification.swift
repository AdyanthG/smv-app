//
//  SMVNotification.swift
//  SMV
//
//  In-app notification model.
//

import Foundation
import SwiftData

@Model
final class SMVNotification {

    @Attribute(.unique)
    var id: String

    var type: NotificationType
    var title: String
    var message: String
    var senderName: String?
    var senderAvatarURL: String?
    var relatedId: String?  // post ID, user ID, challenge ID, etc.
    var isRead: Bool
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        type: NotificationType,
        title: String,
        message: String,
        senderName: String? = nil,
        senderAvatarURL: String? = nil,
        relatedId: String? = nil,
        isRead: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.message = message
        self.senderName = senderName
        self.senderAvatarURL = senderAvatarURL
        self.relatedId = relatedId
        self.isRead = isRead
        self.createdAt = createdAt
    }
}

// MARK: - Notification Type

enum NotificationType: String, Codable {
    case like = "like"
    case comment = "comment"
    case follow = "follow"
    case achievement = "achievement"
    case challenge = "challenge"
    case scanReminder = "scanReminder"
    case scoreImprovement = "scoreImprovement"
    case system = "system"

    var icon: String {
        switch self {
        case .like:             return "heart.fill"
        case .comment:          return "bubble.fill"
        case .follow:           return "person.badge.plus"
        case .achievement:      return "trophy.fill"
        case .challenge:        return "flag.fill"
        case .scanReminder:     return "faceid"
        case .scoreImprovement: return "arrow.up.right"
        case .system:           return "bell.fill"
        }
    }
}
