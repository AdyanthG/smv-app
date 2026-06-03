//
//  SettingsView.swift
//  SMV
//
//  App settings with account management, preferences, and legal links.
//

import SwiftUI
import SwiftData

struct SettingsView: View {

    @Environment(AuthService.self) private var auth
    @Environment(Router.self) private var router
    @Environment(HapticService.self) private var haptics
    @Environment(FirestoreService.self) private var firestore
    @Environment(SubscriptionManager.self) private var subscriptions
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @State private var showDeleteConfirmation = false
    @State private var showSignOutConfirmation = false
    @State private var isDeleting = false
    @State private var notificationsEnabled = true
    @State private var hapticFeedback = true
    @State private var isProfilePublic = true
    @State private var didLoadPrivacy = false

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        List {
            // Account
            Section {
                HStack(spacing: SMVSpacing.md) {
                    AvatarView(name: auth.displayName, size: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(auth.displayName.isEmpty ? "Guest" : auth.displayName)
                            .font(SMVFont.title())
                            .foregroundStyle(.white)
                        Text(auth.currentUserId?.prefix(12) ?? "Not signed in")
                            .font(SMVFont.micro())
                            .foregroundStyle(Color.smvTextTertiary)
                    }
                    Spacer()
                    Button("Edit") { router.push(.editProfile) }
                        .font(SMVFont.caption())
                        .foregroundStyle(Color.smvCyan)
                }
                .listRowBackground(Color.smvSurface1)
            } header: {
                Text("Account")
            }

            // Privacy
            Section {
                Toggle(isOn: $isProfilePublic) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Public Profile")
                                .foregroundStyle(.white)
                            Text("Appear on leaderboards and in voting")
                                .font(SMVFont.micro())
                                .foregroundStyle(Color.smvTextTertiary)
                        }
                    } icon: {
                        Image(systemName: isProfilePublic ? "eye.fill" : "eye.slash.fill")
                    }
                }
                .tint(Color.smvCyan)
                .onChange(of: isProfilePublic) { _, newValue in
                    // Ignore the change that comes from loading the current value.
                    guard didLoadPrivacy else { return }
                    if let userId = auth.currentUserId {
                        Task { await firestore.setProfilePublic(userId: userId, isPublic: newValue) }
                    }
                }
            } header: {
                Text("Privacy")
            }
            .listRowBackground(Color.smvSurface1)

            // Preferences
            Section {
                Toggle(isOn: $notificationsEnabled) {
                    Label("Push Notifications", systemImage: "bell.fill")
                        .foregroundStyle(.white)
                }
                .tint(Color.smvCyan)
                .onChange(of: notificationsEnabled) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: "smv_notificationsEnabled")
                    if let userId = auth.currentUserId {
                        Task { await firestore.setNotificationsEnabled(userId: userId, enabled: newValue) }
                    }
                }

                Toggle(isOn: $hapticFeedback) {
                    Label("Haptic Feedback", systemImage: "hand.tap.fill")
                        .foregroundStyle(.white)
                }
                .tint(Color.smvCyan)
                .onChange(of: hapticFeedback) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: HapticService.prefKey)
                    if newValue { haptics.selection() }
                }
            } header: {
                Text("Preferences")
            }
            .listRowBackground(Color.smvSurface1)

            // Premium
            Section {
                Button {
                    router.present(.paywall)
                } label: {
                    HStack {
                        Label("SMV Pro", systemImage: "crown.fill")
                            .foregroundStyle(Color.smvAmber)
                        Spacer()
                        Text("Upgrade")
                            .font(SMVFont.caption())
                            .foregroundStyle(Color.smvCyan)
                    }
                }

                NavigationLink(value: Router.Destination.referrals) {
                    Label("Invite Friends", systemImage: "gift.fill")
                        .foregroundStyle(.white)
                }

                Button {
                    Task { await subscriptions.restorePurchases() }
                } label: {
                    Label("Restore Purchases", systemImage: "arrow.clockwise")
                        .foregroundStyle(.white)
                }
            } header: {
                Text("Subscription")
            }
            .listRowBackground(Color.smvSurface1)

            // Legal
            Section {
                NavigationLink(value: Router.Destination.privacyPolicy) {
                    Label("Privacy Policy", systemImage: "lock.shield.fill")
                        .foregroundStyle(.white)
                }
                NavigationLink(value: Router.Destination.termsOfService) {
                    Label("Terms of Service", systemImage: "doc.text.fill")
                        .foregroundStyle(.white)
                }
                NavigationLink(value: Router.Destination.communityGuidelines) {
                    Label("Community Guidelines", systemImage: "checkmark.shield.fill")
                        .foregroundStyle(.white)
                }
            } header: {
                Text("Legal")
            }
            .listRowBackground(Color.smvSurface1)

            // Support
            Section {
                Button {
                    composeEmail(subject: "SMV Support Request")
                } label: {
                    Label("Contact Support", systemImage: "envelope.fill")
                        .foregroundStyle(.white)
                }
                Button {
                    composeEmail(subject: "SMV Bug Report")
                } label: {
                    Label("Report a Bug", systemImage: "ladybug.fill")
                        .foregroundStyle(.white)
                }
                HStack {
                    Label("App Version", systemImage: "info.circle.fill")
                        .foregroundStyle(.white)
                    Spacer()
                    Text(appVersion)
                        .font(SMVFont.micro())
                        .foregroundStyle(Color.smvTextTertiary)
                }
            } header: {
                Text("Support")
            }
            .listRowBackground(Color.smvSurface1)

            // Danger zone
            Section {
                Button {
                    showSignOutConfirmation = true
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(Color.smvAmber)
                }

                Button {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete Account", systemImage: "trash.fill")
                        .foregroundStyle(Color.smvPink)
                }
            } header: {
                Text("Account Actions")
            }
            .listRowBackground(Color.smvSurface1)
        }
        .contentMargins(.bottom, 40)
        .scrollContentBackground(.hidden)
        .background(Color.smvBackground)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .confirmationDialog("Sign Out?", isPresented: $showSignOutConfirmation) {
            Button("Sign Out", role: .destructive) {
                auth.signOut()
                router.popToRoot()
            }
        }
        .confirmationDialog("Delete Account?", isPresented: $showDeleteConfirmation) {
            Button("Delete Permanently", role: .destructive) {
                Task { await deleteAccount() }
            }
        } message: {
            Text("This action cannot be undone. All your data will be permanently deleted.")
        }
        .task {
            // Load persisted local preferences.
            let defaults = UserDefaults.standard
            hapticFeedback = defaults.object(forKey: HapticService.prefKey) == nil
                ? true : defaults.bool(forKey: HapticService.prefKey)
            notificationsEnabled = defaults.object(forKey: "smv_notificationsEnabled") == nil
                ? true : defaults.bool(forKey: "smv_notificationsEnabled")

            // Load current privacy setting from Firestore (default public).
            if let userId = auth.currentUserId,
               let data = await firestore.fetchUserProfile(userId: userId) {
                isProfilePublic = data["isProfilePublic"] as? Bool ?? true
            }
            didLoadPrivacy = true
        }
        .overlay {
            if isDeleting {
                ZStack {
                    Color.black.opacity(0.6).ignoresSafeArea()
                    VStack(spacing: SMVSpacing.md) {
                        ProgressView().tint(.white)
                        Text("Deleting account…")
                            .font(SMVFont.caption())
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }

    // MARK: - Account Deletion

    private func deleteAccount() async {
        isDeleting = true
        haptics.warning()

        // 1) Wipe local on-device data so a future account can't see it.
        clearLocalData()

        // 2) Delete the Auth account. This triggers the `cleanupDeletedUser`
        //    Cloud Function, which removes all cloud data server-side (scans,
        //    posts, reciprocal follow edges, comments, and Storage files).
        await auth.deleteAccount()

        isDeleting = false
        router.popToRoot()
    }

    /// Remove all locally-persisted user content (SwiftData).
    private func clearLocalData() {
        try? modelContext.delete(model: ScanResult.self)
        try? modelContext.delete(model: Post.self)
        try? modelContext.delete(model: Comment.self)
        try? modelContext.delete(model: SMVNotification.self)
        try? modelContext.save()
    }

    // MARK: - Support

    private func composeEmail(subject: String) {
        let encoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        if let url = URL(string: "mailto:support@smvapp.com?subject=\(encoded)") {
            openURL(url)
        }
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .environment(AuthService())
        .environment(Router())
        .environment(HapticService())
        .environment(FirestoreService())
}
