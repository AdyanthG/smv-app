//
//  NotificationsView.swift
//  SMV
//
//  In-app notification feed backed by Firestore (users/{uid}/notifications),
//  populated by the Cloud Functions notification system.
//

import SwiftUI
import FirebaseFirestore

struct NotificationsView: View {

    @Environment(AuthService.self) private var auth
    @Environment(FirestoreService.self) private var firestore
    @Environment(Router.self) private var router

    @State private var items: [NotificationFeedItem] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView().tint(Color.smvCyan)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if items.isEmpty {
                emptyState
            } else {
                notificationList
            }
        }
        .background(Color.smvBackground)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await load()
        }
    }

    private var notificationList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(items) { item in
                    Button {
                        router.handleNotification(
                            type: item.type,
                            postId: item.postId,
                            userId: item.userId,
                            tab: item.tab
                        )
                    } label: {
                        notificationRow(item)
                    }
                    .buttonStyle(.plain)

                    Divider().overlay(Color.smvSurface2)
                }
            }
            .padding(.bottom, 40)
        }
    }

    private func notificationRow(_ item: NotificationFeedItem) -> some View {
        HStack(spacing: SMVSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: SMVRadius.sm)
                    .fill(item.accent.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: item.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(item.accent)
            }

            VStack(alignment: .leading, spacing: SMVSpacing.xs) {
                Text(item.title)
                    .font(SMVFont.title())
                    .foregroundStyle(.white)
                Text(item.body)
                    .font(SMVFont.caption())
                    .foregroundStyle(Color.smvTextSecondary)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: SMVSpacing.xs) {
                Text(item.createdAt.relativeShort)
                    .font(SMVFont.micro())
                    .foregroundStyle(Color.smvTextTertiary)
                if !item.read {
                    Circle().fill(Color.smvCyan).frame(width: 8, height: 8)
                }
            }
        }
        .padding(.horizontal, SMVSpacing.lg)
        .padding(.vertical, SMVSpacing.md)
        .background(item.read ? Color.clear : Color.smvSurface0.opacity(0.5))
        .contentShape(Rectangle())
    }

    private var emptyState: some View {
        VStack(spacing: SMVSpacing.lg) {
            Image(systemName: "bell.slash")
                .font(.system(size: 40))
                .foregroundStyle(Color.smvTextTertiary)
            Text("No notifications yet")
                .font(SMVFont.title())
                .foregroundStyle(Color.smvTextSecondary)
            Text("Follows, likes, comments, and milestones will show up here.")
                .font(SMVFont.caption())
                .foregroundStyle(Color.smvTextTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SMVSpacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func load() async {
        guard let userId = auth.currentUserId else {
            isLoading = false
            return
        }
        let raw = await firestore.fetchNotifications(userId: userId)
        items = raw.compactMap { NotificationFeedItem(data: $0) }
        isLoading = false
        // Mark everything read now that the feed has been opened.
        await firestore.markNotificationsRead(userId: userId)
    }
}

// MARK: - Model

struct NotificationFeedItem: Identifiable {
    let id: String
    let title: String
    let body: String
    let type: String
    let postId: String?
    let userId: String?
    let tab: String?
    let read: Bool
    let createdAt: Date

    init?(data: [String: Any]) {
        guard let id = data["id"] as? String else { return nil }
        self.id = id
        self.title = data["title"] as? String ?? "Notification"
        self.body = data["body"] as? String ?? ""
        self.type = data["type"] as? String ?? "general"
        self.postId = data["postId"] as? String
        self.userId = data["userId"] as? String
        self.tab = data["tab"] as? String
        self.read = data["read"] as? Bool ?? false
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? .distantPast
    }

    var icon: String {
        switch type {
        case "follow":         return "person.2.fill"
        case "like":           return "heart.fill"
        case "comment":        return "bubble.left.fill"
        case "vote_milestone": return "trophy.fill"
        case "vote_recap":     return "chart.bar.fill"
        case "daily_scan", "smv_drop": return "bolt.fill"
        case "streak":         return "flame.fill"
        case "dormant":        return "face.smiling.fill"
        default:               return "bell.fill"
        }
    }

    var accent: Color {
        switch type {
        case "follow":         return .smvCyan
        case "like":           return .smvPink
        case "comment":        return .smvViolet
        case "vote_milestone": return .smvAmber
        case "vote_recap":     return .smvViolet
        case "daily_scan", "smv_drop": return .smvCyan
        case "streak":         return .smvPink
        case "dormant":        return .smvAmber
        default:               return .smvCyan
        }
    }
}
