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

    // ── Tabs ── (Feed → Ranks → [Scan] → Community → Profile)

    enum Tab: Int, CaseIterable, Identifiable {
        case feed = 0
        case leaderboard
        case scan
        case community
        case profile

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .feed:        return "Feed"
            case .leaderboard: return "Ranks"
            case .scan:        return "Scan"
            case .community:   return "Community"
            case .profile:     return "Profile"
            }
        }

        var icon: String {
            switch self {
            case .feed:        return "square.stack.fill"
            case .leaderboard: return "trophy.fill"
            case .scan:        return "bolt.fill"
            case .community:   return "bubble.left.and.bubble.right.fill"
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
        case community
        case progress
        case referrals
        case privacyPolicy
        case termsOfService
        case forumCategory(title: String, emoji: String)
        case threadDetail(threadId: String)
        case guideDetail(title: String, emoji: String, author: String, readTime: String)
    }

    // ── Modal Sheets ──

    enum Sheet: Identifiable {
        case createPost
        case paywall
        case scanOptions
        case shareCard(scanId: String)
        case createThread(category: String)

        var id: String {
            switch self {
            case .createPost:              return "createPost"
            case .paywall:                 return "paywall"
            case .scanOptions:             return "scanOptions"
            case .shareCard(let id):       return "shareCard_\(id)"
            case .createThread(let cat):   return "createThread_\(cat)"
            }
        }
    }

    // ── Full-Screen Covers ──

    enum FullScreenDestination: Identifiable {
        case onboarding
        case signIn
        case profileSetup
        case scanning

        var id: String {
            switch self {
            case .onboarding:   return "onboarding"
            case .signIn:       return "signIn"
            case .profileSetup: return "profileSetup"
            case .scanning:     return "scanning"
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
