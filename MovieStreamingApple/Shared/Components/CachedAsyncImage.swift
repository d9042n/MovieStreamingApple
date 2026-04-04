//
//  CachedAsyncImage.swift
//  MovieStreamingApple
//
//  Drop-in replacement for AsyncImage that caches downloaded images
//  in an in-memory NSCache + URLSession's disk cache.
//  Prevents repeated network requests for the same image URL.
//

import SwiftUI

/// Actor-isolated in-memory image cache.
private actor ImageCacheStore {
    static let shared = ImageCacheStore()

    private let cache = NSCache<NSURL, PlatformImage>()

    init() {
        cache.countLimit = 200      // max ~200 images in memory
        cache.totalCostLimit = 100 * 1024 * 1024  // ~100 MB
    }

    func image(for url: URL) -> PlatformImage? {
        cache.object(forKey: url as NSURL)
    }

    func store(_ image: PlatformImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
}

#if os(macOS)
private typealias PlatformImage = NSImage
#else
private typealias PlatformImage = UIImage
#endif

/// A cached version of AsyncImage that avoids re-downloading images.
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var phase: AsyncImagePhase = .empty

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
            switch phase {
            case .success(let image):
                content(image)
            case .failure:
                // Show placeholder on failure — caller can customize
                placeholder()
            case .empty:
                placeholder()
            @unknown default:
                placeholder()
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let url else {
            phase = .failure(URLError(.badURL))
            return
        }

        // 1. Check in-memory cache
        if let cached = await ImageCacheStore.shared.image(for: url) {
            #if os(macOS)
            phase = .success(Image(nsImage: cached))
            #else
            phase = .success(Image(uiImage: cached))
            #endif
            return
        }

        // 2. Download (URLSession's default disk cache also applies)
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard !Task.isCancelled else { return }

            guard let platformImage = PlatformImage(data: data) else {
                phase = .failure(URLError(.cannotDecodeContentData))
                return
            }

            // Store in memory cache
            await ImageCacheStore.shared.store(platformImage, for: url)

            #if os(macOS)
            phase = .success(Image(nsImage: platformImage))
            #else
            phase = .success(Image(uiImage: platformImage))
            #endif
        } catch {
            guard !Task.isCancelled else { return }
            phase = .failure(error)
        }
    }
}

// MARK: - Convenience Init (matches AsyncImage API)

extension CachedAsyncImage where Placeholder == ProgressView<EmptyView, EmptyView> {
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content
    ) {
        self.init(url: url, content: content, placeholder: { ProgressView() })
    }
}
