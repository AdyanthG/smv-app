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

    @Environment(\.dismiss) private var dismiss
    @Environment(FirestoreService.self) private var firestore
    @Environment(AuthService.self) private var auth

    @State private var images: [GalleryImage] = []
    @State private var currentIndex: Int = 0
    @State private var isLoading = true

    // For own scans, try SwiftData first
    @Query(sort: \ScanResult.timestamp, order: .reverse) private var scans: [ScanResult]

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
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFit()
                                            .clipShape(RoundedRectangle(cornerRadius: SMVRadius.lg))
                                    case .failure:
                                        imagePlaceholder
                                    default:
                                        ProgressView()
                                            .tint(Color.smvCyan)
                                    }
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

        if isOwnProfile, let latestScan = scans.first {
            // Load from local SwiftData
            var result: [GalleryImage] = []
            if let data = latestScan.imageData, let img = UIImage(data: data) {
                result.append(GalleryImage(label: "Front", uiImage: img))
            }
            if let data = latestScan.leftImageData, let img = UIImage(data: data) {
                result.append(GalleryImage(label: "Left", uiImage: img))
            }
            if let data = latestScan.rightImageData, let img = UIImage(data: data) {
                result.append(GalleryImage(label: "Right", uiImage: img))
            }
            if let data = latestScan.upImageData, let img = UIImage(data: data) {
                result.append(GalleryImage(label: "Up", uiImage: img))
            }
            if let data = latestScan.downImageData, let img = UIImage(data: data) {
                result.append(GalleryImage(label: "Down", uiImage: img))
            }
            images = result
        } else {
            // Load from Firestore URLs
            let gallery = await firestore.fetchScanGalleryURLs(userId: userId)
            images = gallery.compactMap { item in
                guard let url = URL(string: item.url) else { return nil }
                return GalleryImage(label: item.angle, url: url)
            }
        }

        isLoading = false
    }
}

// MARK: - Gallery Image Model

private struct GalleryImage: Identifiable {
    let id = UUID()
    let label: String
    var uiImage: UIImage? = nil
    var url: URL? = nil
}
