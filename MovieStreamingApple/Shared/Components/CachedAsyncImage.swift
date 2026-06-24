//
//  CachedAsyncImage.swift
//  MovieStreamingApple
//
//  Drop-in replacement for AsyncImage that caches downloaded images
//  in an in-memory NSCache + URLSession's disk cache.
//  Prevents repeated network requests for the same image URL.
//

import SwiftUI

/// In-memory image cache. `NSCache` is already thread-safe, so a plain
/// (`@unchecked Sendable`) class avoids the extra actor-hop `await` on every
/// cache read/write (#12).
private final class ImageCacheStore: @unchecked Sendable {
    static let shared = ImageCacheStore()

    private let cache = NSCache<NSURL, PlatformImage>()

    init() {
        cache.countLimit = 200      // max ~200 images in memory
        cache.totalCostLimit = 100 * 1024 * 1024  // ~100 MB
    }

    func image(for url: URL) -> PlatformImage? {
        cache.object(forKey: url as NSURL)
    }

    func store(_ image: PlatformImage, for url: URL, cost: Int) {
        // Supplying a byte cost makes `totalCostLimit` (the ~100 MB budget)
        // actually govern eviction — without it every object has cost 0 and only
        // `countLimit` ever applies.
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }
}

#if os(macOS)
private typealias PlatformImage = NSImage
#else
private typealias PlatformImage = UIImage
#endif

private extension PlatformImage {
    /// Estimated decoded byte footprint (RGBA), used as the NSCache cost.
    var estimatedCacheCost: Int {
        #if os(macOS)
        return max(1, Int(size.width * size.height * 4))
        #else
        return max(1, Int(size.width * scale * size.height * scale * 4))
        #endif
    }
}

/// A cached version of AsyncImage that avoids re-downloading images.
struct CachedAsyncImage<Content: View, Placeholder: View, Failure: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    let failure: () -> Failure

    @State private var phase: AsyncImagePhase = .empty

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder,
        @ViewBuilder failure: @escaping () -> Failure
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
        self.failure = failure
    }

    var body: some View {
        Group {
            switch phase {
            case .success(let image):
                content(image)
            case .failure:
                // Distinct failure view — avoids showing a spinning placeholder
                // forever when an image URL is broken (#2).
                failure()
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

        // 1. Check in-memory cache (cache hit → show immediately, no flash)
        if let cached = ImageCacheStore.shared.image(for: url) {
            #if os(macOS)
            phase = .success(Image(nsImage: cached))
            #else
            phase = .success(Image(uiImage: cached))
            #endif
            return
        }

        // Cache miss: reset to the placeholder for the NEW url so a recycled view
        // (grid/list cell, hero slide) never shows the PREVIOUS url's image while
        // the new one downloads. (AsyncImage resets on url change; this didn't.)
        if case .empty = phase {} else { phase = .empty }

        // 2. Download (URLSession's default disk cache also applies)
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard !Task.isCancelled else { return }

            guard let platformImage = PlatformImage(data: data) else {
                phase = .failure(URLError(.cannotDecodeContentData))
                return
            }

            // Store in memory cache with an estimated byte cost so the memory
            // budget (totalCostLimit) is enforced, not just the count limit.
            ImageCacheStore.shared.store(platformImage, for: url, cost: platformImage.estimatedCacheCost)

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

// MARK: - Default Failure View

/// Neutral fallback shown when an image fails to load.
/// Fills the parent frame so it works for posters, avatars, and thumbnails.
struct CachedImageFailureView: View {
    var body: some View {
        ZStack {
            Rectangle().fill(Color(white: 0.12))
            Image(systemName: "photo")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(.white.opacity(0.25))
        }
    }
}

// MARK: - Convenience Inits (matches AsyncImage API)

extension CachedAsyncImage where Failure == CachedImageFailureView {
    /// content + placeholder, with the default failure fallback.
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.init(url: url, content: content, placeholder: placeholder, failure: { CachedImageFailureView() })
    }
}

extension CachedAsyncImage where Placeholder == ProgressView<EmptyView, EmptyView>, Failure == CachedImageFailureView {
    /// content only — ProgressView placeholder + default failure fallback.
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content
    ) {
        self.init(
            url: url,
            content: content,
            placeholder: { ProgressView() },
            failure: { CachedImageFailureView() }
        )
    }
}
