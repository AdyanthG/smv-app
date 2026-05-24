//
//  NotificationsView.swift
//  SMV
//
//  Notification feed — milestones, rank changes, updates.
//

import SwiftUI

struct NotificationsView: View {

    // Mock notifications
    private let notifications: [NotificationItem] = [
        NotificationItem(icon: "chart.line.uptrend.xyaxis", title: "Score Improved", subtitle: "Your score went up +0.3 since last scan", time: "2h ago", accent: .smvEmerald),
        NotificationItem(icon: "trophy.fill", title: "Rank Up", subtitle: "You moved to #47 on the global leaderboard", time: "5h ago", accent: .smvAmber),
        NotificationItem(icon: "flame.fill", title: "7 Day Streak", subtitle: "Keep scanning daily to track your progress", time: "1d ago", accent: .smvPink),
        NotificationItem(icon: "person.2.fill", title: "New Follower", subtitle: "jaydenk started following you", time: "2d ago", accent: .smvCyan),
        NotificationItem(icon: "chart.bar.fill", title: "Weekly Summary", subtitle: "Your average score this week: 5.4", time: "3d ago", accent: .smvViolet),
    ]

    var body: some View {
        NavigationStack {
            Group {
                if notifications.isEmpty {
                    emptyState
                } else {
                    notificationList
                }
            }
            .background(Color.smvBackground)
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var notificationList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(notifications) { item in
                    notificationRow(item)
                    Divider()
                        .overlay(Color.smvSurface2)
                }
            }
        }
    }

    private func notificationRow(_ item: NotificationItem) -> some View {
        HStack(spacing: SMVSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: SMVRadius.sm)
                    .fill(item.accent.opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: item.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(item.accent)
            }

            VStack(alignment: .leading, spacing: SMVSpacing.xs) {
                Text(item.title)
                    .font(SMVFont.title())
                    .foregroundStyle(.white)
                Text(item.subtitle)
                    .font(SMVFont.caption())
                    .foregroundStyle(Color.smvTextSecondary)
            }

            Spacer()

            Text(item.time)
                .font(SMVFont.micro())
                .foregroundStyle(Color.smvTextTertiary)
        }
        .padding(.horizontal, SMVSpacing.lg)
        .padding(.vertical, SMVSpacing.md)
    }

    private var emptyState: some View {
        VStack(spacing: SMVSpacing.lg) {
            Image(systemName: "bell.slash")
                .font(.system(size: 40))
                .foregroundStyle(Color.smvTextTertiary)
            Text("No notifications yet")
                .font(SMVFont.title())
                .foregroundStyle(Color.smvTextSecondary)
            Text("Start scanning to get score updates and milestones")
                .font(SMVFont.caption())
                .foregroundStyle(Color.smvTextTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Notification Model

struct NotificationItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let time: String
    let accent: Color
}
