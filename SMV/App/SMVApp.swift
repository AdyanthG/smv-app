//
//  SMVApp.swift
//  SMV
//
//  Created by Adyanth Ganesh on 5/14/26.
//
//  Main entry point — sets up data persistence, routing, and the root view.
//

import SwiftUI
import SwiftData

@main
struct SMVApp: App {

    // ── SwiftData ──
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
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
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    // ── App State ──
    @State private var router = Router()
    @State private var haptics = HapticService()
    @State private var auth = AuthService()
    @State private var subscriptions = SubscriptionManager()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(router)
                .environment(haptics)
                .environment(auth)
                .environment(subscriptions)
                .preferredColorScheme(.dark)
                .task {
                    await subscriptions.updateSubscriptionStatus()
                }
                .onAppear {
                    if !auth.isOnboarded {
                        router.presentFullScreen(.onboarding)
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
