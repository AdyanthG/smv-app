//
//  NotificationService.swift
//  SMV
//
//  Push notification service using Firebase Cloud Messaging.
//  Handles permission requests, token registration, and payload routing.
//

import Foundation
import UserNotifications
import FirebaseMessaging
import UIKit

@Observable
final class NotificationService: NSObject {

    var isPermissionGranted: Bool = false
    var fcmToken: String?

    override init() {
        super.init()
        Messaging.messaging().delegate = self
    }

    // MARK: - Permission

    func requestPermission() async {
        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            await MainActor.run {
                self.isPermissionGranted = granted
            }
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        } catch {
            print("[NotificationService] Permission error: \(error)")
        }
    }

    func checkCurrentPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run {
            isPermissionGranted = settings.authorizationStatus == .authorized
        }
    }

    // MARK: - Token Storage

    func registerToken(userId: String, firestore: FirestoreService) async {
        guard let token = fcmToken else { return }
        await firestore.saveFCMToken(userId: userId, token: token)
    }

    // MARK: - Local Notifications (for in-app events)

    func scheduleLocalNotification(
        title: String,
        body: String,
        delay: TimeInterval = 1.0,
        identifier: String = UUID().uuidString
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    /// Schedule a streak reminder notification
    func scheduleStreakReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Don't break your streak! 🔥"
        content.body = "You haven't scanned today. Keep your streak alive."
        content.sound = .default

        // Fire at 8 PM daily
        var dateComponents = DateComponents()
        dateComponents.hour = 20
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "streak_reminder", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - MessagingDelegate

extension NotificationService: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        self.fcmToken = token
        print("[NotificationService] FCM token: \(token.prefix(20))...")
    }
}
