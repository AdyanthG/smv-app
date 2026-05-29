//
//  CachedAsyncImage.swift
//  SMV
//
//  Cached async image loader that avoids re-fetching on every view
//  reappearance. Uses NSCache for in-memory caching.
//

import SwiftUI

/// In-memory image cache shared across the app
final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }

    func image(for key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func setImage(_ image: UIImage, for key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
}

struct CachedAsyncImage<Content: View, Placeholder: View>: View {

    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var cachedImage: UIImage?
    @State private var isLoading = false

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let cachedImage {
                content(Image(uiImage: cachedImage))
            } else {
                placeholder()
                    .task(id: url) {
                        await loadImage()
                    }
            }
        }
    }

    private func loadImage() async {
        guard let url, !isLoading else { return }

        let key = url.absoluteString

        // Check cache first
        if let cached = ImageCache.shared.image(for: key) {
            cachedImage = cached
            return
        }

        isLoading = true

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                ImageCache.shared.setImage(image, for: key)
                await MainActor.run {
                    cachedImage = image
                }
            }
        } catch {
            // Silently fail — placeholder will remain
        }

        isLoading = false
    }
}
