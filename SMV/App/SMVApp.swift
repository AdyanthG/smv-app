//
//  SMVApp.swift
//  SMV
//
//  Created by Adyanth Ganesh on 5/14/26.
//
//  Main entry point — Firebase init, data persistence, routing, root view.
//

import SwiftUI
import SwiftData
import FirebaseCore

// Firebase app delegate for initialization
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct SMVApp: App {

    // Register the Firebase app delegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

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
    @State private var firestore = FirestoreService()
    @State private var storage = StorageService()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(router)
                .environment(haptics)
                .environment(auth)
                .environment(subscriptions)
                .environment(firestore)
                .environment(storage)
                .preferredColorScheme(.dark)
                .task {
                    auth.start()
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
