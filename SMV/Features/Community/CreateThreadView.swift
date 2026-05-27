//
//  CreateThreadView.swift
//  SMV
//
//  Sheet to create a new forum thread.
//

import SwiftUI
import SwiftData

struct CreateThreadView: View {

    let category: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var auth
    @Environment(HapticService.self) private var haptics
    @State private var title = ""
    @State private var bodyText = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SMVSpacing.xxl) {
                    // Category badge
                    HStack(spacing: SMVSpacing.sm) {
                        Text("Posting in")
                            .font(SMVFont.caption())
                            .foregroundStyle(Color.smvTextSecondary)
                        Text(category)
                            .font(SMVFont.caption())
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.smvCyan)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.smvCyan.opacity(0.1)))
                    }

                    // Title
                    VStack(alignment: .leading, spacing: SMVSpacing.sm) {
                        Text("TITLE")
                            .font(SMVFont.micro())
                            .foregroundStyle(Color.smvTextTertiary)
                            .tracking(1)
                        TextField("Thread title...", text: $title)
                            .font(SMVFont.body())
                            .foregroundStyle(.white)
                            .padding(SMVSpacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: SMVRadius.sm)
                                    .fill(Color.smvSurface1)
                            )
                    }

                    // Body
                    VStack(alignment: .leading, spacing: SMVSpacing.sm) {
                        Text("BODY")
                            .font(SMVFont.micro())
                            .foregroundStyle(Color.smvTextTertiary)
                            .tracking(1)
                        TextField("What's on your mind?", text: $bodyText, axis: .vertical)
                            .font(SMVFont.body())
                            .foregroundStyle(.white)
                            .lineLimit(5...15)
                            .padding(SMVSpacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: SMVRadius.sm)
                                    .fill(Color.smvSurface1)
                            )
                    }
                }
                .padding(.horizontal, SMVSpacing.xxl)
                .padding(.top, SMVSpacing.xxl)
            }
            .background(Color.smvBackground)
            .navigationTitle("New Thread")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.smvTextSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") { createThread() }
                        .foregroundStyle(Color.smvCyan)
                        .fontWeight(.semibold)
                        .disabled(title.isEmpty)
                }
            }
        }
    }

    private func createThread() {
        haptics.mediumImpact()

        let thread = ForumThread(
            categoryId: category,
            authorId: auth.currentUserId ?? "guest",
            authorName: auth.displayName.isEmpty ? "You" : auth.displayName,
            authorHandle: UserDefaults.standard.string(forKey: "smv_handle") ?? "user",
            title: title,
            body: bodyText
        )
        modelContext.insert(thread)
        dismiss()
    }
}
