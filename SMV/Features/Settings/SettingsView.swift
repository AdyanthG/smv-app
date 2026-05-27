//
//  SettingsView.swift
//  SMV
//
//  App settings with account management, preferences, and legal links.
//

import SwiftUI

struct SettingsView: View {

    @Environment(AuthService.self) private var auth
    @Environment(Router.self) private var router
    @Environment(HapticService.self) private var haptics
    @State private var showDeleteConfirmation = false
    @State private var showSignOutConfirmation = false
    @State private var notificationsEnabled = true
    @State private var hapticFeedback = true

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

            // Preferences
            Section {
                Toggle(isOn: $notificationsEnabled) {
                    Label("Push Notifications", systemImage: "bell.fill")
                        .foregroundStyle(.white)
                }
                .tint(Color.smvCyan)

                Toggle(isOn: $hapticFeedback) {
                    Label("Haptic Feedback", systemImage: "hand.tap.fill")
                        .foregroundStyle(.white)
                }
                .tint(Color.smvCyan)
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

                Button { } label: {
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
                Button { } label: {
                    Label("Community Guidelines", systemImage: "checkmark.shield.fill")
                        .foregroundStyle(.white)
                }
            } header: {
                Text("Legal")
            }
            .listRowBackground(Color.smvSurface1)

            // Support
            Section {
                Button { } label: {
                    Label("Contact Support", systemImage: "envelope.fill")
                        .foregroundStyle(.white)
                }
                Button { } label: {
                    Label("Report a Bug", systemImage: "ladybug.fill")
                        .foregroundStyle(.white)
                }
                HStack {
                    Label("App Version", systemImage: "info.circle.fill")
                        .foregroundStyle(.white)
                    Spacer()
                    Text("1.0.0 (1)")
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
                Task {
                    await auth.deleteAccount()
                    router.popToRoot()
                }
            }
        } message: {
            Text("This action cannot be undone. All your data will be permanently deleted.")
        }
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .environment(AuthService())
        .environment(Router())
        .environment(HapticService())
}
