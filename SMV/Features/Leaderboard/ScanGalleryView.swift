//
//  ScanGalleryView.swift
//  SMV
//
//  Full-screen swipeable gallery showing all scan angle images.
//  Works for own scans (SwiftData) and other users (Firestore URLs).
//

import SwiftUI
import SwiftData

struct ScanGalleryView: View {

    let userId: String
    let displayName: String
    /// Show this exact scan (by Firestore doc id). Takes precedence over scoreField.
    var scanId: String? = nil
    /// Show the scan with the highest value in this scan-doc field (e.g. "overallScore").
    var scoreField: String? = nil
    /// Initial angle to display.
    var startIndex: Int = 0

    @Environment(\.dismiss) private var dismiss
    @Environment(FirestoreService.self) private var firestore
    @Environment(AuthService.self) private var auth

    @State private var images: [GalleryImage] = []
    @State private var currentIndex: Int = 0
    @State private var isLoading = true

    // For own scans, try SwiftData first (scoped to the profile's user)
    @Query(sort: \ScanResult.timestamp, order: .reverse) private var allScans: [ScanResult]

    private var scans: [ScanResult] {
        allScans.filter { $0.userId == userId }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .tint(Color.smvCyan)
            } else if images.isEmpty {
                VStack(spacing: SMVSpacing.lg) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.smvTextTertiary)
                    Text("No scan images available")
                        .font(SMVFont.body())
                        .foregroundStyle(Color.smvTextSecondary)
                }
            } else {
                TabView(selection: $currentIndex) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, item in
                        VStack(spacing: 0) {
                            if let uiImage = item.uiImage {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .clipShape(RoundedRectangle(cornerRadius: SMVRadius.lg))
                                    .padding(.horizontal, SMVSpacing.md)
                            } else if let url = item.url {
                                // CachedAsyncImage keys its load on the URL, so a
                                // recycled TabView page reloads for its new angle
                                // instead of showing the previous scan's image.
                                CachedAsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .clipShape(RoundedRectangle(cornerRadius: SMVRadius.lg))
                                } placeholder: {
                                    ProgressView()
                                        .tint(Color.smvCyan)
                                }
                                .padding(.horizontal, SMVSpacing.md)
                            }

                            Text(item.label)
                                .font(SMVFont.caption())
                                .foregroundStyle(Color.smvTextSecondary)
                                .padding(.top, SMVSpacing.md)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                // Page indicator dots
                VStack {
                    Spacer()
                    Text("\(currentIndex + 1) / \(images.count)")
                        .font(SMVFont.micro())
                        .foregroundStyle(Color.smvTextTertiary)
                        .padding(.bottom, 60)
                }
            }

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.smvTextSecondary)
                    }
                    .padding(SMVSpacing.lg)
                }
                Spacer()
            }

            // Title
            VStack {
                Text(displayName)
                    .font(SMVFont.headline())
                    .foregroundStyle(.white)
                    .padding(.top, SMVSpacing.xxl)
                Spacer()
            }
        }
        .task {
            await loadImages()
        }
    }

    private var imagePlaceholder: some View {
        RoundedRectangle(cornerRadius: SMVRadius.lg)
            .fill(Color.smvSurface1)
            .frame(width: 200, height: 280)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.smvTextTertiary)
            )
    }

    private func loadImages() async {
        let isOwnProfile = userId == auth.currentUserId

        // Resolve the local scan to show (own profile only).
        let localScan: ScanResult? = {
            guard isOwnProfile else { return nil }
            if let scanId {
                return scans.first { $0.id == scanId }
            }
            if let scoreField {
                return scans.max { localScore($0, field: scoreField) < localScore($1, field: scoreField) }
            }
            return scans.first // latest
        }()

        if let localScan {
            images = localImages(from: localScan)
        } else {
            // Load from Firestore URLs, picking the right scan.
            let gallery: [(angle: String, url: String)]
            if let scanId {
                gallery = await firestore.fetchScanGalleryForScan(scanId: scanId)
            } else if let scoreField {
                gallery = await firestore.fetchScanGallery(userId: userId, scoreField: scoreField).images
            } else {
                gallery = await firestore.fetchScanGalleryURLs(userId: userId)
            }
            images = gallery.compactMap { item in
                guard let url = URL(string: item.url) else { return nil }
                return GalleryImage(label: item.angle, url: url)
            }
        }

        // Clamp the initial angle to the available images.
        if !images.isEmpty {
            currentIndex = min(max(0, startIndex), images.count - 1)
        }
        isLoading = false
    }

    /// Build gallery images from a local SwiftData scan.
    private func localImages(from scan: ScanResult) -> [GalleryImage] {
        let angles: [(String, Data?)] = [
            ("Front", scan.imageData),
            ("Left", scan.leftImageData),
            ("Right", scan.rightImageData),
            ("Up", scan.upImageData),
            ("Down", scan.downImageData),
        ]
        return angles.compactMap { label, data in
            guard let data, let img = UIImage(data: data) else { return nil }
            return GalleryImage(label: label, uiImage: img)
        }
    }

    /// Read a scan's score for a given scan-doc field name.
    private func localScore(_ scan: ScanResult, field: String) -> Double {
        switch field {
        case "eyeAreaScore":     return scan.eyeAreaScore
        case "jawScore":         return scan.jawScore
        case "symmetryScore":    return scan.symmetryScore
        case "harmonyScore":     return scan.harmonyScore
        case "proportionsScore": return scan.proportionsScore
        case "skinClarityScore": return scan.skinClarityScore
        default:                 return scan.overallScore
        }
    }
}

// MARK: - Gallery Image Model

private struct GalleryImage: Identifiable {
    let id = UUID()
    let label: String
    var uiImage: UIImage? = nil
    var url: URL? = nil
}
