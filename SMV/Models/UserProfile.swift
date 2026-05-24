//
//  UserProfile.swift
//  SMV
//
//  User profile model persisted with SwiftData.
//

import Foundation
import SwiftData

@Model
final class UserProfile {

    @Attribute(.unique)
    var id: String

    var displayName: String
    var handle: String
    var bio: String
    var avatarURL: String?
    var joinDate: Date
    var currentScore: Double?
    var highScore: Double?
    var scanCount: Int
    var streakDays: Int
    var followerCount: Int
    var followingCount: Int
    var isPremium: Bool
    var gender: Gender
    var goals: [String]

    // Computed: tier derived from current score
    var tier: ScoreTier {
        ScoreTier.from(score: currentScore ?? 0)
    }

    init(
        id: String = UUID().uuidString,
        displayName: String = "",
        handle: String = "",
        bio: String = "",
        avatarURL: String? = nil,
        joinDate: Date = .now,
        currentScore: Double? = nil,
        highScore: Double? = nil,
        scanCount: Int = 0,
        streakDays: Int = 0,
        followerCount: Int = 0,
        followingCount: Int = 0,
        isPremium: Bool = false,
        gender: Gender = .unspecified,
        goals: [String] = []
    ) {
        self.id = id
        self.displayName = displayName
        self.handle = handle
        self.bio = bio
        self.avatarURL = avatarURL
        self.joinDate = joinDate
        self.currentScore = currentScore
        self.highScore = highScore
        self.scanCount = scanCount
        self.streakDays = streakDays
        self.followerCount = followerCount
        self.followingCount = followingCount
        self.isPremium = isPremium
        self.gender = gender
        self.goals = goals
    }
}

// MARK: - Gender

enum Gender: String, Codable, CaseIterable {
    case male = "Male"
    case female = "Female"
    case other = "Other"
    case unspecified = "Prefer not to say"
}
