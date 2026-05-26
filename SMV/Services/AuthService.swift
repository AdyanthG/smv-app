//
//  AuthService.swift
//  SMV
//
//  Firebase Authentication service.
//  Supports Sign in with Apple, anonymous/guest sign-in, and account management.
//

import SwiftUI
import FirebaseAuth
import AuthenticationServices
import CryptoKit

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

    private var authStateListener: AuthStateDidChangeListenerHandle?
    private var currentNonce: String?

    // On-device prefs (onboarding flag)
    private let defaults = UserDefaults.standard
    private let kOnboarded = "smv_onboarded"

    var isOnboarded: Bool {
        defaults.bool(forKey: kOnboarded)
    }

    // MARK: - Init

    init() {
        listenToAuthState()
    }

    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    // MARK: - Auth State Listener

    private func listenToAuthState() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            if let user {
                self.displayName = user.displayName ?? defaults.string(forKey: "smv_displayName") ?? ""
                self.email = user.email ?? ""
                self.avatarURL = user.photoURL?.absoluteString
                self.state = .signedIn(userId: user.uid)
            } else {
                self.state = .signedOut
            }
        }
    }

    // MARK: - Sign In with Apple

    /// Call this to get the ASAuthorization request configured for Firebase
    func prepareAppleSignIn() -> ASAuthorizationAppleIDRequest {
        let nonce = randomNonceString()
        currentNonce = nonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        return request
    }

    /// Handle the Apple Sign In result
    func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        isLoading = true
        errorMessage = nil

        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let appleIDToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: appleIDToken, encoding: .utf8),
                  let nonce = currentNonce else {
                errorMessage = "Apple Sign In failed — invalid credentials"
                isLoading = false
                return
            }

            let credential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: appleIDCredential.fullName
            )

            do {
                let authResult = try await Auth.auth().signIn(with: credential)

                // Store display name if Apple provided it (only on first sign-in)
                if let fullName = appleIDCredential.fullName {
                    let name = [fullName.givenName, fullName.familyName]
                        .compactMap { $0 }
                        .joined(separator: " ")
                    if !name.isEmpty {
                        let changeRequest = authResult.user.createProfileChangeRequest()
                        changeRequest.displayName = name
                        try? await changeRequest.commitChanges()
                        displayName = name
                        defaults.set(name, forKey: "smv_displayName")
                    }
                }

                state = .signedIn(userId: authResult.user.uid)
            } catch {
                errorMessage = error.localizedDescription
            }

        case .failure(let error):
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Sign In with Apple (Simple async — for onboarding)

    func signInWithApple() async {
        // This is called from the onboarding view which uses SignInWithAppleButton
        // The actual auth is handled via prepareAppleSignIn + handleAppleSignIn
        // This method exists for backward compatibility with views that call it directly
        isLoading = true
        errorMessage = nil

        // If no Firebase user yet, sign in anonymously as fallback
        if Auth.auth().currentUser == nil {
            do {
                let result = try await Auth.auth().signInAnonymously()
                displayName = "User"
                defaults.set("User", forKey: "smv_displayName")
                state = .signedIn(userId: result.user.uid)
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    // MARK: - Guest Sign In (Anonymous)

    func signInAsGuest() {
        Task {
            isLoading = true
            do {
                let result = try await Auth.auth().signInAnonymously()
                displayName = "Guest"
                defaults.set("Guest", forKey: "smv_displayName")
                state = .signedIn(userId: result.user.uid)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    // MARK: - Profile Setup

    func completeProfileSetup(name: String, handle: String) {
        defaults.set(name, forKey: "smv_displayName")
        defaults.set(handle, forKey: "smv_handle")
        displayName = name

        // Update Firebase profile
        if let user = Auth.auth().currentUser {
            let changeRequest = user.createProfileChangeRequest()
            changeRequest.displayName = name
            changeRequest.commitChanges(completion: nil)
        }
    }

    func completeOnboarding() {
        defaults.set(true, forKey: kOnboarded)
    }

    // MARK: - Sign Out

    func signOut() {
        do {
            try Auth.auth().signOut()
            displayName = ""
            email = ""
            avatarURL = nil
            state = .signedOut
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Delete Account

    func deleteAccount() async {
        isLoading = true

        do {
            try await Auth.auth().currentUser?.delete()
            defaults.removeObject(forKey: "smv_displayName")
            defaults.removeObject(forKey: "smv_handle")
            defaults.removeObject(forKey: kOnboarded)
            displayName = ""
            email = ""
            avatarURL = nil
            state = .signedOut
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Apple Sign In Helpers

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        guard errorCode == errSecSuccess else {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}
