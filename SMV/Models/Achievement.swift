//
//  Achievement.swift
//  SMV
//
//  Gamification achievement/badge model.
//

import Foundation
import SwiftData

@Model
final class Achievement {

    @Attribute(.unique)
    var id: String

    var title: String
    var achievementDescription: String
    var emoji: String
    var category: AchievementCategory
    var isUnlocked: Bool
    var unlockedDate: Date?
    var progress: Double  // 0.0 to 1.0
    var requirement: String

    init(
        id: String = UUID().uuidString,
        title: String,
        achievementDescription: String,
        emoji: String,
        category: AchievementCategory = .scanning,
        isUnlocked: Bool = false,
        unlockedDate: Date? = nil,
        progress: Double = 0,
        requirement: String = ""
    ) {
        self.id = id
        self.title = title
        self.achievementDescription = achievementDescription
        self.emoji = emoji
        self.category = category
        self.isUnlocked = isUnlocked
        self.unlockedDate = unlockedDate
        self.progress = progress
        self.requirement = requirement
    }
}

// MARK: - Category

enum AchievementCategory: String, Codable, CaseIterable {
    case scanning = "Scanning"
    case social = "Social"
    case streaks = "Streaks"
    case scores = "Scores"
    case community = "Leaderboard"
}

// MARK: - Default Achievements

extension Achievement {

    static let defaults: [(title: String, desc: String, emoji: String, cat: AchievementCategory, req: String)] = [
        ("First Scan",     "Complete your first face scan",            "📸", .scanning,  "1 scan"),
        ("Dedicated",      "Complete 10 face scans",                   "🎯", .scanning,  "10 scans"),
        ("Veteran",        "Complete 50 face scans",                   "🏅", .scanning,  "50 scans"),
        ("7-Day Streak",   "Scan 7 days in a row",                    "🔥", .streaks,   "7-day streak"),
        ("30-Day Streak",  "Scan 30 days in a row",                   "💪", .streaks,   "30-day streak"),
        ("Precision",      "Score 9.0+ on any attribute",             "🎯", .scores,    "9.0+ attribute"),
        ("Glow Up",        "Improve overall score by 1.0+",           "📈", .scores,    "+1.0 overall"),
        ("Diamond Tier",   "Reach an overall score of 9.0+",          "💎", .scores,    "9.0+ overall"),
        ("Top 100",        "Reach the global top 100",                "👑", .community, "Top 100 rank"),
        ("Influencer",     "Gain 100+ followers",                     "🤝", .social,    "100 followers"),
        ("Viral",          "Get 500+ likes on a single post",         "🌟", .social,    "500 likes"),
        ("First Post",     "Share your first scan to the feed",       "✍️", .social,    "1 post"),
    ]
}
