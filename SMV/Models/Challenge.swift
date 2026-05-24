//
//  Challenge.swift
//  SMV
//
//  Community challenge model.
//

import Foundation
import SwiftData

@Model
final class Challenge {

    @Attribute(.unique)
    var id: String

    var title: String
    var challengeDescription: String
    var emoji: String
    var category: LeaderboardCategory
    var startDate: Date
    var endDate: Date
    var participantCount: Int
    var isJoined: Bool
    var userRank: Int?
    var userScore: Double?

    var isActive: Bool {
        Date.now >= startDate && Date.now <= endDate
    }

    var daysRemaining: Int {
        max(0, Calendar.current.dateComponents([.day], from: .now, to: endDate).day ?? 0)
    }

    init(
        id: String = UUID().uuidString,
        title: String,
        challengeDescription: String = "",
        emoji: String = "🏆",
        category: LeaderboardCategory = .global,
        startDate: Date = .now,
        endDate: Date = .now.addingTimeInterval(7 * 24 * 3600),
        participantCount: Int = 0,
        isJoined: Bool = false,
        userRank: Int? = nil,
        userScore: Double? = nil
    ) {
        self.id = id
        self.title = title
        self.challengeDescription = challengeDescription
        self.emoji = emoji
        self.category = category
        self.startDate = startDate
        self.endDate = endDate
        self.participantCount = participantCount
        self.isJoined = isJoined
        self.userRank = userRank
        self.userScore = userScore
    }
}
