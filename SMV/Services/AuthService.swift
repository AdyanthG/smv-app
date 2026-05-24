//
//  AuthService.swift
//  SMV
//
//  Authentication service — protocol-based for Firebase swap.
//  Currently uses local/mock auth; swap implementation when
//  GoogleService-Info.plist + Firebase SDK are added.
//

import SwiftUI

// MARK: - Auth State

enum AuthState: Equatable {
    case unknown
    case signedOut
    case signedIn(userId: String)
}

// MARK: - Auth Service

@Observable
final class AuthService {

    var state: AuthState = .unknown
    var currentUserId: String? {
        if case .signedIn(let id) = state { return id }
        return nil
    }
    var displayName: String = ""
    var email: String = ""
    var avatarURL: String?
    var isLoading = false
    var errorMessage: String?

    // On-device auth for MVP — stores in UserDefaults
    private let defaults = UserDefaults.standard
    private let kUserId = "smv_user_id"
    private let kDisplayName = "smv_display_name"
    private let kEmail = "smv_email"
    private let kOnboarded = "smv_onboarded"

    var isOnboarded: Bool {
        defaults.bool(forKey: kOnboarded)
    }

    // MARK: - Init

    init() {
        restoreSession()
    }

    // MARK: - Session

    func restoreSession() {
        if let userId = defaults.string(forKey: kUserId) {
            displayName = defaults.string(forKey: kDisplayName) ?? ""
            email = defaults.string(forKey: kEmail) ?? ""
            state = .signedIn(userId: userId)
        } else {
            state = .signedOut
        }
    }

    // MARK: - Sign In (Local MVP)

    func signInWithApple() async {
        isLoading = true
        errorMessage = nil
        // Simulate Apple Sign In — in production, use AuthenticationServices
        try? await Task.sleep(for: .milliseconds(800))
        let userId = UUID().uuidString
        defaults.set(userId, forKey: kUserId)
        defaults.set("SMV User", forKey: kDisplayName)
        displayName = "SMV User"
        state = .signedIn(userId: userId)
        isLoading = false
    }

    func signInAsGuest() {
        let userId = "guest_\(UUID().uuidString.prefix(8))"
        defaults.set(userId, forKey: kUserId)
        defaults.set("Guest", forKey: kDisplayName)
        displayName = "Guest"
        state = .signedIn(userId: userId)
    }

    // MARK: - Profile Setup

    func completeProfileSetup(name: String, handle: String) {
        defaults.set(name, forKey: kDisplayName)
        displayName = name
    }

    func completeOnboarding() {
        defaults.set(true, forKey: kOnboarded)
    }

    // MARK: - Sign Out

    func signOut() {
        defaults.removeObject(forKey: kUserId)
        defaults.removeObject(forKey: kDisplayName)
        defaults.removeObject(forKey: kEmail)
        displayName = ""
        email = ""
        state = .signedOut
    }

    // MARK: - Delete Account

    func deleteAccount() async {
        isLoading = true
        try? await Task.sleep(for: .milliseconds(500))
        defaults.removeObject(forKey: kUserId)
        defaults.removeObject(forKey: kDisplayName)
        defaults.removeObject(forKey: kEmail)
        defaults.removeObject(forKey: kOnboarded)
        displayName = ""
        email = ""
        state = .signedOut
        isLoading = false
    }
}
