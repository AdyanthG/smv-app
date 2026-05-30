//
//  LeaderboardEntry.swift
//  SMV
//
//  Leaderboard ranking entry model.
//

import Foundation
import SwiftData

@Model
final class LeaderboardEntry {

    @Attribute(.unique)
    var id: String

    var userId: String
    var displayName: String
    var handle: String
    var avatarURL: String?
    var score: Double
    var previousScore: Double?
    var rank: Int
    var scanCount: Int
    var category: LeaderboardCategory

    var scoreChange: Double? {
        guard let prev = previousScore else { return nil }
        return score - prev
    }

    var tier: ScoreTier {
        ScoreTier.from(score: score)
    }

    init(
        id: String = UUID().uuidString,
        userId: String,
        displayName: String,
        handle: String,
        avatarURL: String? = nil,
        score: Double,
        previousScore: Double? = nil,
        rank: Int,
        scanCount: Int = 0,
        category: LeaderboardCategory = .global
    ) {
        self.id = id
        self.userId = userId
        self.displayName = displayName
        self.handle = handle
        self.avatarURL = avatarURL
        self.score = score
        self.previousScore = previousScore
        self.rank = rank
        self.scanCount = scanCount
        self.category = category
    }
}

// MARK: - Category

enum LeaderboardCategory: String, Codable, CaseIterable {
    case global = "Global"
    case eyeArea = "Eye Area"
    case jawline = "Jawline"
    case symmetry = "Symmetry"
    case harmony = "Harmony"
    case proportions = "Proportions"
    case skinClarity = "Skin"
    case mostImproved = "Most Improved"
    case mostVoted = "Most Voted"

    /// The Firestore field name used for ranking in this category
    var firestoreField: String {
        switch self {
        case .global:       return "bestScore"
        case .eyeArea:      return "bestEyeAreaScore"
        case .jawline:      return "bestJawScore"
        case .symmetry:     return "bestSymmetryScore"
        case .harmony:      return "bestHarmonyScore"
        case .proportions:  return "bestProportionsScore"
        case .skinClarity:  return "bestSkinClarityScore"
        case .mostImproved: return "improvementRate"
        case .mostVoted:    return "voteWins"
        }
    }

    /// Categories whose value is a count/rate rather than a 0–10 score.
    var isCountMetric: Bool { self == .mostVoted }

    /// The field on a *scan* document corresponding to this category. Used to
    /// find the specific scan that earned a user's rank (vs. the user aggregate
    /// `firestoreField`). Most Improved has no single scan → use overall best.
    var scanField: String {
        switch self {
        case .global, .mostImproved, .mostVoted: return "overallScore"
        case .eyeArea:               return "eyeAreaScore"
        case .jawline:               return "jawScore"
        case .symmetry:              return "symmetryScore"
        case .harmony:               return "harmonyScore"
        case .proportions:           return "proportionsScore"
        case .skinClarity:           return "skinClarityScore"
        }
    }
}
