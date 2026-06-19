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

    /// User tapped a push — broadcast its payload so the UI can deep-link.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        await MainActor.run {
            NotificationCenter.default.post(
                name: .smvNotificationTapped,
                object: nil,
                userInfo: userInfo
            )
        }
    }
}

extension Notification.Name {
    static let smvNotificationTapped = Notification.Name("smvNotificationTapped")
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

                    // Notification permission is requested contextually during
                    // onboarding (not cold on launch). Re-check status and register
                    // the FCM token if already authorized.
                    await notifications.checkCurrentPermission()
                    if let userId = auth.currentUserId {
                        await notifications.registerToken(userId: userId, firestore: firestore)
                    }
                }
                .onChange(of: notifications.fcmToken) {
                    // The FCM token arrives asynchronously (and can rotate) — persist
                    // it whenever it changes so push delivery has a current token.
                    if let userId = auth.currentUserId {
                        Task { await notifications.registerToken(userId: userId, firestore: firestore) }
                    }
                }
                .onAppear {
                    // Show onboarding/sign-in if not authenticated
                    if !auth.isOnboarded {
                        router.presentFullScreen(.onboarding)
                    }
                }
                .onChange(of: auth.state) { _, newState in
                    switch newState {
                    case .signedIn(let userId):
                        // Register the FCM token against the signed-in account.
                        Task { await notifications.registerToken(userId: userId, firestore: firestore) }
                    case .signedOut:
                        // Show onboarding again on sign-out.
                        router.presentFullScreen(.onboarding)
                    case .unknown:
                        break
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
