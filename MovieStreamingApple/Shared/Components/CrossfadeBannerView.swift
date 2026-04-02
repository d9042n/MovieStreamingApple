//
//  CrossfadeBannerView.swift
//  MovieStreamingApple
//
//  Shared immersive crossfade carousel banner.
//  Used by both ContentDetail and PersonDetail to avoid duplicated
//  banner logic (~70 lines of code deduplication).
//

import SwiftUI

struct CrossfadeBannerView: View {
    let imageURLs: [URL]
    var imageOpacity: Double = 0.85
    var autoAdvanceInterval: TimeInterval = 9.2

    @State private var currentIndex = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if imageURLs.isEmpty {
                    gradientFallback
                } else {
                    // Crossfade carousel — only render current ± 1 for memory optimization
                    ZStack {
                        ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, url in
                            if isVisible(index) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(
                                                width: geometry.size.width,
                                                height: geometry.size.height
                                            )
                                            .kenBurns(
                                                isActive: currentIndex == index,
                                                maxScale: 1.08,
                                                duration: 8.0,
                                                reverse: !index.isMultiple(of: 2),
                                                repeats: false,
                                                startDelay: 1.2
                                            )
                                            .clipped()
                                    case .failure:
                                        if index == 0 {
                                            gradientFallback
                                        } else {
                                            Color.clear
                                        }
                                    default:
                                        if index == currentIndex {
                                            shimmerPlaceholder
                                        } else {
                                            Color.clear
                                        }
                                    }
                                }
                                .opacity(currentIndex == index ? imageOpacity : 0)
                            }
                        }
                    }
                }

                // Bottom gradient
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.6), .black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: geometry.size.height * 0.65)
                }

                // Side vignettes
                LinearGradient(
                    colors: [.black.opacity(0.3), .clear, .black.opacity(0.3)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .task(id: currentIndex) {
            guard imageURLs.count > 1 else { return }
            try? await Task.sleep(for: .seconds(autoAdvanceInterval))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 1.2)) {
                currentIndex = (currentIndex + 1) % imageURLs.count
            }
        }
    }

    /// Only render current, previous, and next images for memory optimization.
    /// This prevents loading 6-8 full-res images simultaneously.
    private func isVisible(_ index: Int) -> Bool {
        let count = imageURLs.count
        guard count > 0 else { return false }
        if count <= 3 { return true }
        let prev = (currentIndex - 1 + count) % count
        let next = (currentIndex + 1) % count
        return index == currentIndex || index == prev || index == next
    }

    private var gradientFallback: some View {
        LinearGradient(
            colors: [Color(white: 0.15), .black],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var shimmerPlaceholder: some View {
        Rectangle()
            .fill(Color(white: 0.12))
            .overlay {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.04), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
    }
}
