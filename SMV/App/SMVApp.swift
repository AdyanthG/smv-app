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
import FirebaseMessaging

// Firebase app delegate for initialization
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        // Register for remote notifications
        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .badge, .sound]
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
            Comment.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Schema changed — wipe the old store and retry
            // This is expected during development when adding new model fields
            print("[SMVApp] ModelContainer failed, wiping store: \(error)")
            let url = config.url
            let fm = FileManager.default
            // Remove the main store and its journal files
            for suffix in ["", "-shm", "-wal"] {
                let fileURL = URL(fileURLWithPath: url.path() + suffix)
                try? fm.removeItem(at: fileURL)
            }
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Could not create ModelContainer after reset: \(error)")
            }
        }
    }()

    // ── App State ──
    @State private var router = Router()
    @State private var haptics = HapticService()
    @State private var auth = AuthService()
    @State private var subscriptions = SubscriptionManager()
    @State private var firestore = FirestoreService()
    @State private var storage = StorageService()
    @State private var notifications = NotificationService()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(router)
                .environment(haptics)
                .environment(auth)
                .environment(subscriptions)
                .environment(firestore)
                .environment(storage)
                .environment(notifications)
                .preferredColorScheme(.dark)
                .task {
                    auth.start()
                    await subscriptions.updateSubscriptionStatus()
                    // Request push permission
                    await notifications.requestPermission()

                    // Auto sign-in anonymously if not signed in
                    // This ensures scans are saved to Firestore for leaderboard
                    if auth.currentUserId == nil {
                        auth.signInAsGuest()
                        // Wait briefly for sign-in to complete
                        try? await Task.sleep(for: .milliseconds(500))
                    }

                    // Register FCM token
                    if let userId = auth.currentUserId {
                        await notifications.registerToken(userId: userId, firestore: firestore)
                    }
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
