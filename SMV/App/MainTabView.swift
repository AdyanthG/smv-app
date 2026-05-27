//
//  MainTabView.swift
//  SMV
//
//  Root view with custom bottom tab bar and navigation.
//

import SwiftUI
import SwiftData

struct MainTabView: View {

    @Environment(Router.self) private var router

    var body: some View {
        @Bindable var router = router

        ZStack(alignment: .bottom) {
            // ── Active Tab Content ──
            NavigationStack(path: $router.navigationPath) {
                TabContent(tab: router.selectedTab)
                    .navigationDestination(for: Router.Destination.self) { dest in
                        switch dest {
                        case .scanResults(let scanId):
                            ResultsView(scanId: scanId)
                        case .userProfile(let userId):
                            UserProfileView(userId: userId, displayName: "User", score: 5.0)
                        case .postDetail(let postId):
                            Text("Post: \(postId)")
                        case .settings:
                            SettingsView()
                        case .editProfile:
                            EditProfileView()
                        case .notifications:
                            NotificationsView()
                        case .challengeDetail(let id):
                            Text("Challenge: \(id)")
                        case .community:
                            CommunityView()
                        case .progress:
                            ScoreProgressView()
                        }
                    }
            }
            .tint(Color.smvCyan)

            // ── Tab Bar ──
            CustomTabBar()
        }
        .background(Color.smvBackground)
        .ignoresSafeArea(.keyboard)
        .sheet(item: $router.presentedSheet) { sheet in
            switch sheet {
            case .createPost:
                CreatePostView()
            case .paywall:
                PaywallView()
            case .scanOptions:
                Text("Scan Options")
            case .shareCard(let scanId):
                Text("Share: \(scanId)")
            }
        }
        .fullScreenCover(item: $router.presentedFullScreen) { dest in
            switch dest {
            case .onboarding:
                OnboardingView()
            case .signIn:
                Text("Sign In")
            case .profileSetup:
                Text("Profile Setup")
            case .scanning:
                ScanView()
            }
        }
    }
}

// MARK: - Tab Content

private struct TabContent: View {
    let tab: Router.Tab

    var body: some View {
        switch tab {
        case .feed:
            FeedView()
        case .leaderboard:
            LeaderboardView()
        case .scan:
            ScanView()
        case .community:
            CommunityView()
        case .profile:
            ProfileView()
        }
    }
}

// MARK: - Custom Tab Bar

private struct CustomTabBar: View {

    @Environment(Router.self) private var router

    private let tabs: [Router.Tab] = Router.Tab.allCases

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(tabs) { tab in
                    if tab == .scan {
                        ScanTabButton()
                    } else {
                        TabBarButton(tab: tab)
                    }
                }
            }
            .padding(.horizontal, SMVSpacing.sm)
            .padding(.top, SMVSpacing.md)
            .padding(.bottom, SMVSpacing.sm)
        }
        .background(
            Rectangle()
                .fill(Color.smvSurface0.opacity(0.95))
                .ignoresSafeArea(.container, edges: .bottom)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 0.5)
                }
        )
    }
}

// MARK: - Tab Bar Button

private struct TabBarButton: View {

    let tab: Router.Tab
    @Environment(Router.self) private var router

    private var isSelected: Bool { router.selectedTab == tab }

    var body: some View {
        Button {
            withAnimation(.spring(duration: 0.3)) {
                router.switchTab(tab)
            }
        } label: {
            Image(systemName: tab.icon)
                .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                .symbolEffect(.bounce, value: isSelected)
            .foregroundStyle(isSelected ? Color.smvCyan : Color.smvTextTertiary)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Scan Tab (Floating)

private struct ScanTabButton: View {

    @Environment(Router.self) private var router
    var body: some View {
        Button {
            withAnimation(.spring(duration: 0.3)) {
                router.switchTab(.scan)
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color.smvCyan)
                    .frame(width: 52, height: 52)
                    .overlay(
                        Circle()
                            .stroke(Color.smvCyan.opacity(0.3), lineWidth: 1)
                            .frame(width: 58, height: 58)
                    )

                Image(systemName: "bolt.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }
            .offset(y: -12)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    MainTabView()
        .environment(Router())
        .environment(HapticService())
        .environment(AuthService())
        .environment(SubscriptionManager())
        .modelContainer(for: [
            UserProfile.self,
            ScanResult.self,
            Post.self,
            LeaderboardEntry.self,
            Challenge.self,
            Achievement.self,
            SMVNotification.self,
            ForumCategory.self,
            ForumThread.self,
            ForumReply.self,
        ], inMemory: true)
}
