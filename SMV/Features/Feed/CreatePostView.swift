//
//  CreatePostView.swift
//  SMV
//
//  Sheet to create a new feed post.
//

import SwiftUI
import SwiftData

struct CreatePostView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(Router.self) private var router
    @Environment(AuthService.self) private var auth
    @Environment(FirestoreService.self) private var firestore
    @Environment(HapticService.self) private var haptics
    @Query(sort: \ScanResult.timestamp, order: .reverse) private var allScans: [ScanResult]
    @State private var caption: String = ""
    @State private var selectedHashtags: Set<String> = []
    @State private var attachScanResult: Bool = true
    @State private var isPublic: Bool = true
    @State private var isPosting = false

    /// Only the current account's scans.
    private var scans: [ScanResult] {
        guard let uid = auth.currentUserId else { return allScans }
        return allScans.filter { $0.userId == uid }
    }

    private let suggestedHashtags = [
        "looksmaxxing", "glowup", "smvcheck", "mewing",
        "jawline", "skincare", "transformation", "progress",
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SMVSpacing.xxl) {
                    // Caption
                    VStack(alignment: .leading, spacing: SMVSpacing.sm) {
                        Text("CAPTION")
                            .font(SMVFont.micro())
                            .foregroundStyle(Color.smvTextTertiary)
                            .tracking(1)
                        TextField("Share your journey...", text: $caption, axis: .vertical)
                            .font(SMVFont.body())
                            .foregroundStyle(.white)
                            .lineLimit(4...8)
                            .padding(SMVSpacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: SMVRadius.sm)
                                    .fill(Color.smvSurface1)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: SMVRadius.sm)
                                            .stroke(Color.white.opacity(0.04), lineWidth: 0.5)
                                    )
                            )
                    }

                    // Attach scan result toggle
                    HStack {
                        Image(systemName: "viewfinder")
                            .foregroundStyle(Color.smvCyan)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Attach latest scan result")
                                .font(SMVFont.body())
                                .foregroundStyle(.white)
                            if attachScanResult && scans.isEmpty {
                                Text("No scans yet to attach")
                                    .font(SMVFont.micro())
                                    .foregroundStyle(Color.smvTextTertiary)
                            }
                        }
                        Spacer()
                        Toggle("", isOn: $attachScanResult)
                            .labelsHidden()
                            .tint(Color.smvCyan)
                            .disabled(scans.isEmpty)
                    }
                    .padding(SMVSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: SMVRadius.sm)
                            .fill(Color.smvSurface1)
                    )

                    // Visibility toggle
                    HStack {
                        Image(systemName: isPublic ? "globe" : "lock.fill")
                            .foregroundStyle(Color.smvCyan)
                        Text(isPublic ? "Public — visible in the feed" : "Private — only you")
                            .font(SMVFont.body())
                            .foregroundStyle(.white)
                        Spacer()
                        Toggle("", isOn: $isPublic)
                            .labelsHidden()
                            .tint(Color.smvCyan)
                    }
                    .padding(SMVSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: SMVRadius.sm)
                            .fill(Color.smvSurface1)
                    )

                    // Hashtags
                    VStack(alignment: .leading, spacing: SMVSpacing.sm) {
                        Text("HASHTAGS")
                            .font(SMVFont.micro())
                            .foregroundStyle(Color.smvTextTertiary)
                            .tracking(1)

                        FlowLayout(spacing: SMVSpacing.sm) {
                            ForEach(suggestedHashtags, id: \.self) { tag in
                                Button {
                                    if selectedHashtags.contains(tag) {
                                        selectedHashtags.remove(tag)
                                    } else {
                                        selectedHashtags.insert(tag)
                                    }
                                } label: {
                                    Text("#\(tag)")
                                        .font(SMVFont.caption())
                                        .foregroundStyle(selectedHashtags.contains(tag) ? .white : Color.smvTextSecondary)
                                        .padding(.horizontal, SMVSpacing.md)
                                        .padding(.vertical, SMVSpacing.sm)
                                        .background(
                                            Capsule()
                                                .fill(selectedHashtags.contains(tag) ? Color.smvCyan.opacity(0.2) : Color.smvSurface2)
                                        )
                                }
                            }
                        }
                    }

                    // Preview
                    if !caption.isEmpty {
                        VStack(alignment: .leading, spacing: SMVSpacing.sm) {
                            Text("PREVIEW")
                                .font(SMVFont.micro())
                                .foregroundStyle(Color.smvTextTertiary)
                                .tracking(1)
                            GlassmorphicCard {
                                VStack(alignment: .leading, spacing: SMVSpacing.sm) {
                                    Text(caption)
                                        .font(SMVFont.body())
                                        .foregroundStyle(.white)
                                    if !selectedHashtags.isEmpty {
                                        Text(selectedHashtags.map { "#\($0)" }.joined(separator: " "))
                                            .font(SMVFont.caption())
                                            .foregroundStyle(Color.smvCyan)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, SMVSpacing.xxl)
                .padding(.top, SMVSpacing.xxl)
            }
            .background(Color.smvBackground)
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.smvTextSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") { createPost() }
                        .foregroundStyle(Color.smvCyan)
                        .fontWeight(.semibold)
                        .disabled(caption.isEmpty || isPosting)
                }
            }
        }
    }

    private func createPost() {
        isPosting = true
        haptics.mediumImpact()

        let userId = auth.currentUserId ?? "local_user"
        let name = auth.displayName.isEmpty ? "You" : auth.displayName
        let handle = UserDefaults.standard.string(forKey: "smv_handle") ?? "user"
        let avatarURL = auth.avatarURL

        // Resolve attached scan details from the latest local scan.
        let attachedScan = attachScanResult ? scans.first : nil
        let scanResultId = attachedScan?.id
        let authorScore = attachedScan?.overallScore
        let scoreChange: Double? = {
            guard let latest = attachedScan, scans.count > 1 else { return nil }
            return latest.overallScore - scans[1].overallScore
        }()

        // Save locally so it shows immediately in own-post views.
        let post = Post(
            authorId: userId,
            authorName: name,
            authorHandle: handle,
            authorAvatarURL: avatarURL,
            authorScore: authorScore,
            caption: caption,
            hashtags: Array(selectedHashtags),
            scanResultId: scanResultId,
            scoreChange: scoreChange,
            isPublic: isPublic
        )
        modelContext.insert(post)

        // Save to Firestore, resolving the scan's front image URL first.
        let captionValue = caption
        let hashtagsValue = Array(selectedHashtags)
        let publicValue = isPublic
        Task {
            var imageURL: String?
            if scanResultId != nil {
                imageURL = await firestore.fetchLatestScanImages(userId: userId)["front"]
                if let imageURL {
                    post.imageURL = imageURL
                }
            }
            let _ = await firestore.savePost(
                authorId: userId,
                authorName: name,
                authorHandle: handle,
                caption: captionValue,
                hashtags: hashtagsValue,
                scanResultId: scanResultId,
                authorScore: authorScore,
                authorAvatarURL: avatarURL,
                imageURL: imageURL,
                scoreChange: scoreChange,
                isPublic: publicValue
            )

            // Tell the feed to reload now that the post exists in Firestore.
            router.refreshFeed()
        }

        dismiss()
    }
}

// MARK: - Flow Layout (for hashtag chips)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}
