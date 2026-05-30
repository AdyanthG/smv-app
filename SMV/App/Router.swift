//
//  Router.swift
//  SMV
//
//  Enum-based navigation router with NavigationStack support.
//

import SwiftUI

// MARK: - Router

@Observable
final class Router {

    var selectedTab: Tab = .feed
    var navigationPath = NavigationPath()
    var presentedSheet: Sheet?
    var presentedFullScreen: FullScreenDestination?

    /// Bumped after a new post is created so the feed reloads to show it.
    var feedRefreshToken: Int = 0
    func refreshFeed() { feedRefreshToken += 1 }

    // ── Tabs ── (Feed → Ranks → [Scan] → Community → Profile)

    enum Tab: Int, CaseIterable, Identifiable {
        case feed = 0
        case leaderboard
        case scan
        case vote
        case profile

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .feed:        return "Feed"
            case .leaderboard: return "Ranks"
            case .scan:        return "Scan"
            case .vote:        return "Vote"
            case .profile:     return "Profile"
            }
        }

        var icon: String {
            switch self {
            case .feed:        return "square.stack.fill"
            case .leaderboard: return "trophy.fill"
            case .scan:        return "bolt.fill"
            case .vote:        return "hand.thumbsup.fill"
            case .profile:     return "person.fill"
            }
        }
    }

    // ── Push Destinations ──

    enum Destination: Hashable {
        case scanResults(scanId: String)
        case userProfile(userId: String)
        case postDetail(postId: String)
        case settings
        case editProfile
        case notifications
        case challengeDetail(challengeId: String)
        case progress
        case referrals
        case privacyPolicy
        case termsOfService
        case communityGuidelines
        case scanHistory
        case scanDetail(userId: String, scanId: String)
    }

    // ── Modal Sheets ──

    enum Sheet: Identifiable {
        case createPost
        case paywall
        case scanGallery(userId: String, displayName: String, scanId: String? = nil, scoreField: String? = nil, startIndex: Int = 0)

        var id: String {
            switch self {
            case .createPost:              return "createPost"
            case .paywall:                 return "paywall"
            case .scanGallery(let userId, _, let scanId, let scoreField, _):
                return "scanGallery_\(userId)_\(scanId ?? scoreField ?? "latest")"
            }
        }
    }

    // ── Full-Screen Covers ──

    enum FullScreenDestination: Identifiable {
        case onboarding

        var id: String {
            switch self {
            case .onboarding:   return "onboarding"
            }
        }
    }

    // ── Navigation Helpers ──

    func push(_ destination: Destination) {
        navigationPath.append(destination)
    }

    func pop() {
        guard !navigationPath.isEmpty else { return }
        navigationPath.removeLast()
    }

    func popToRoot() {
        navigationPath = NavigationPath()
    }

    func switchTab(_ tab: Tab) {
        if selectedTab == tab {
            popToRoot()
        } else {
            selectedTab = tab
        }
    }

    func present(_ sheet: Sheet) {
        presentedSheet = sheet
    }

    func presentFullScreen(_ destination: FullScreenDestination) {
        presentedFullScreen = destination
    }

    func dismiss() {
        presentedSheet = nil
        presentedFullScreen = nil
    }
}
