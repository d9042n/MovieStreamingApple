//
//  HeroSliderView.swift
//  MovieStreamingApple
//
//  Auto-advancing hero carousel — Netflix/Disney+ cinematic style.
//  Full-bleed image (.fill) with content overlaid on bottom gradient.
//  Ken Burns: ultra-subtle 2% zoom so subjects aren't lost.
//  Dynamic Island: strong top gradient blends the notch area.
//

import SwiftUI

struct HeroSliderView: View {
    let contents: [Content]

    @State private var currentIndex = 0
    @State private var isOnScreen = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.themeManager) private var themeManager
    @Environment(\.horizontalSizeClass) private var hSizeClass

    /// Auto-advance only runs when the slider is actually visible and the app is
    /// active — avoids burning CPU/battery animating off-screen (#10).
    private var autoAdvanceActive: Bool {
        isOnScreen && scenePhase == .active && !reduceMotion && contents.count > 1
    }

    /// `currentIndex` clamped to the current `contents` bounds. Reading through
    /// this everywhere prevents an out-of-range subscript crash when `contents`
    /// shrinks on refresh while a larger `currentIndex` is still retained (#crash).
    private var safeIndex: Int {
        guard !contents.isEmpty else { return 0 }
        return min(max(currentIndex, 0), contents.count - 1)
    }

    var body: some View {
        if contents.isEmpty {
            emptyPlaceholder
        } else {
            ZStack(alignment: .bottom) {
                // ── Crossfade carousel (replaces TabView swipe) ──
                ZStack {
                    ForEach(Array(contents.enumerated()), id: \.element.id) { index, item in
                        // Only render current ±1 slides to reduce GPU/memory usage
                        let distance = min(abs(index - safeIndex), contents.count - abs(index - safeIndex))
                        if distance <= 1 {
                            HeroSlideView(
                                content: item,
                                isActive: safeIndex == index,
                                reduceMotion: reduceMotion,
                                reverseZoom: !index.isMultiple(of: 2)
                            )
                            .opacity(safeIndex == index ? 1 : 0)
                        }
                    }
                }
                .aspectRatio(hSizeClass == .regular ? 16.0 / 9.0 : 2.0 / 3.0, contentMode: .fit)

                // Ambient brand glow — cinematic color bleed
                ambientGlow

                // Custom page indicator
                pageIndicator
                    .padding(.bottom, DesignTokens.Spacing.lg)
            }
            .task(id: "\(safeIndex)-\(autoAdvanceActive)") {
                guard autoAdvanceActive else { return }
                try? await Task.sleep(for: .seconds(9.2))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 1.2)) {
                    currentIndex = (safeIndex + 1) % contents.count
                }
            }
            .onScrollVisibilityChange(threshold: 0.2) { visible in
                isOnScreen = visible
            }
            // Clamp the stored index when the dataset shrinks (e.g. pull-to-refresh
            // returns fewer hero items) so the page indicator and auto-advance stay valid.
            .onChange(of: contents.count) { _, newCount in
                if currentIndex >= newCount {
                    currentIndex = max(0, newCount - 1)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 40)
                    .onEnded { value in
                        // Only act on predominantly horizontal swipes
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        guard contents.count > 1 else { return }

                        withAnimation(.easeInOut(duration: 1.2)) {
                            if value.translation.width < -50 {
                                currentIndex = (safeIndex + 1) % contents.count
                            } else if value.translation.width > 50 {
                                currentIndex = (safeIndex - 1 + contents.count) % contents.count
                            }
                        }
                    }
            )
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Nổi bật: \(contents[safeIndex].title), slide \(safeIndex + 1) trên \(contents.count)")
            .accessibilityAdjustableAction { direction in
                withAnimation(.easeInOut(duration: 1.2)) {
                    switch direction {
                    case .increment:
                        currentIndex = (safeIndex + 1) % contents.count
                    case .decrement:
                        currentIndex = (safeIndex - 1 + contents.count) % contents.count
                    @unknown default:
                        break
                    }
                }
            }
        }
    }

    // MARK: - Page Indicator

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<contents.count, id: \.self) { index in
                Capsule()
                    .fill(index == safeIndex ? themeManager.colors.brand : ThemeColor.textPrimary.opacity(0.3))
                    .frame(width: index == safeIndex ? 28 : 8, height: 6)
                    .shadow(color: index == safeIndex ? themeManager.colors.brand.opacity(0.6) : .clear, radius: 6)
                    .animation(reduceMotion ? .none : DesignTokens.Animation.standard, value: safeIndex)
            }
        }
    }

    // MARK: - Empty State

    private var emptyPlaceholder: some View {
        Rectangle()
            .fill(themeManager.colors.bgCard)
            .aspectRatio(hSizeClass == .regular ? 16.0 / 9.0 : 2.0 / 3.0, contentMode: .fit)
            .overlay {
                VStack(spacing: DesignTokens.Spacing.md) {
                    Image(systemName: AppIcon.film)
                        .font(ThemeFont.display(size: 40))
                        .foregroundStyle(themeManager.colors.textBody)
                    Text("Đang tải nội dung...")
                        .font(ThemeFont.body(size: 12))
                        .foregroundStyle(themeManager.colors.textMuted)
                        .textCase(.uppercase)
                }
            }
    }

    // MARK: - Ambient Brand Glow

    private var ambientGlow: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.0),
                .init(color: themeManager.colors.brand.opacity(0.06), location: 0.3),
                .init(color: themeManager.colors.brand.opacity(0.15), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 80)
        .blur(radius: 20)
        .allowsHitTesting(false)
    }
}

// MARK: - Individual Slide (Cinematic Overlay)

private struct HeroSlideView: View {
    let content: Content
    let isActive: Bool
    let reduceMotion: Bool
    let reverseZoom: Bool

    @Environment(\.themeManager) private var themeManager
    @Environment(\.horizontalSizeClass) private var hSizeClass

    // Stagger animation states
    @State private var showBadges = false
    @State private var showTitle = false
    @State private var showOriginalTitle = false
    @State private var showMeta = false
    @State private var showGenres = false
    @State private var showDescription = false
    @State private var showButton = false

    // #3/#26: Single stored+cancellable Task for stagger animation
    @State private var staggerTask: Task<Void, Never>?

    // Trailer sheet
    @State private var showTrailer = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                // ── LAYER 1: Full-bleed image ──
                CachedAsyncImage(url: backdropURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .kenBurns(isActive: isActive, maxScale: 1.10, duration: 8.0, reverse: reverseZoom, repeats: false, startDelay: 1.2)
                        .clipped()
                } placeholder: {
                    Rectangle()
                        .fill(Color(white: 0.06))
                        .overlay { ProgressView().tint(.white.opacity(0.3)) }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()

                // ── LAYER 2: Gradients ──
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black.opacity(0.08), location: 0.35),
                        .init(color: .black.opacity(0.4), location: 0.55),
                        .init(color: .black.opacity(0.8), location: 0.75),
                        .init(color: .black.opacity(0.95), location: 0.9),
                        .init(color: .black, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack {
                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0.7), location: 0.0),
                            .init(color: .black.opacity(0.35), location: 0.5),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 120)
                    Spacer()
                }

                // ── LAYER 3: Content overlay ──
                VStack(alignment: .leading, spacing: 0) {
                    Spacer()

                    // Badges
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Label(
                            content.isFeatured == true ? "Hot Release" : "Trending Now",
                            systemImage: "flame.fill"
                        )
                        .font(ThemeFont.display(size: 11, weight: .heavy))
                        .foregroundStyle(themeManager.colors.brand)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(themeManager.colors.brand.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(themeManager.colors.brand.opacity(0.3), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                        Label(
                            content.type == .series ? "TV Series" : "Phim Lẻ",
                            systemImage: content.type == .series ? "tv" : "film"
                        )
                        .font(ThemeFont.display(size: 11, weight: .medium))
                        .foregroundStyle(themeManager.colors.textPrimary)
                    }
                    .padding(.bottom, 8)
                    .opacity(showBadges ? 1 : 0)
                    .offset(y: showBadges ? 0 : 12)

                    // Title
                    Text(content.title)
                        .font(ThemeFont.display(size: 26, weight: .heavy))
                        .foregroundStyle(themeManager.colors.textInverse)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: 56, alignment: .bottomLeading)
                        .shadow(color: .black.opacity(0.7), radius: 10, y: 3)
                        .opacity(showTitle ? 1 : 0)
                        .offset(y: showTitle ? 0 : 14)

                    // Original title
                    Group {
                        if let original = content.originalTitle, original != content.title {
                            Text(original)
                                .font(ThemeFont.body(size: 14))
                                .foregroundStyle(themeManager.colors.textInverse.opacity(0.55))
                                .italic()
                                .lineLimit(1)
                        } else {
                            Color.clear
                        }
                    }
                    .frame(height: 20)
                    .padding(.bottom, 6)
                    .opacity(showOriginalTitle ? 1 : 0)
                    .offset(y: showOriginalTitle ? 0 : 10)

                    // Meta chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            if let rating = content.averageRating, rating > 0 {
                                metaChip(
                                    icon: "star.fill",
                                    text: String(format: "%.1f", rating),
                                    chipColor: themeManager.colors.highlight,
                                    iconColor: themeManager.colors.highlight
                                )
                            }

                            if let year = content.releaseYear {
                                metaChip(text: String(year))
                            }

                            if let duration = content.formattedDuration {
                                metaChip(icon: "clock", text: duration)
                            } else if content.type == .series, let epCount = content.episodeCount {
                                metaChip(
                                    icon: "clock",
                                    text: "\(content.seasonCount ?? 1)S · \(epCount)Ep"
                                )
                            }

                            if let views = content.formattedViews {
                                metaChip(icon: "eye", text: views, chipColor: themeManager.colors.highlight, iconColor: themeManager.colors.highlight)
                            }

                            if let quality = content.streamingMeta?.quality, !quality.isEmpty {
                                metaChip(text: quality.uppercased())
                            }
                        }
                    }
                    .frame(height: 28)
                    .padding(.bottom, 8)
                    .opacity(showMeta ? 1 : 0)
                    .offset(y: showMeta ? 0 : 10)

                    // Genres
                    Group {
                        if let genres = content.genres, !genres.isEmpty {
                            HStack(spacing: 6) {
                                ForEach(Array(genres.prefix(3).enumerated()), id: \.offset) { _, genre in
                                    Text(genre.name)
                                        .font(ThemeFont.body(size: 11, weight: .bold))
                                        .foregroundStyle(themeManager.colors.textInverse.opacity(0.7))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(themeManager.colors.textInverse.opacity(0.08))
                                        .overlay(
                                            Capsule()
                                                .stroke(themeManager.colors.textInverse.opacity(0.12), lineWidth: 1)
                                        )
                                        .clipShape(Capsule())
                                }
                            }
                        } else {
                            Color.clear
                        }
                    }
                    .frame(height: 24)
                    .padding(.bottom, 8)
                    .opacity(showGenres ? 1 : 0)
                    .offset(y: showGenres ? 0 : 10)

                    // Description
                    Group {
                        if let desc = content.description?.strippingHTML, !desc.isEmpty {
                            Text(desc)
                                .font(ThemeFont.body(size: 13))
                                .foregroundStyle(themeManager.colors.textInverse.opacity(0.75))
                                .lineLimit(2)
                                .lineSpacing(2)
                        } else {
                            Color.clear
                        }
                    }
                    .frame(height: 44, alignment: .top)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 12)
                    .opacity(showDescription ? 1 : 0)
                    .offset(y: showDescription ? 0 : 10)

                    // Action buttons
                    HStack(spacing: DesignTokens.Spacing.md) {
                        NavigationLink(value: content) {
                            Label("Xem Ngay", systemImage: "play.fill")
                                .font(ThemeFont.display(size: 14, weight: .bold))
                                .textCase(.uppercase)
                                .foregroundStyle(themeManager.colors.textInverse)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    LinearGradient(
                                        colors: [themeManager.colors.brand, themeManager.colors.brandHover],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(Capsule())
                                .shadow(
                                    color: themeManager.colors.brand.opacity(0.4),
                                    radius: 15, y: 4
                                )
                        }
                        .buttonStyle(.plain)

                        // #16: Trailer button opens sheet instead of navigating to detail
                        Button {
                            showTrailer = true
                        } label: {
                            Label("Trailer", systemImage: "play")
                                .font(ThemeFont.display(size: 14, weight: .bold))
                                .foregroundStyle(themeManager.colors.textInverse.opacity(content.trailerUrl != nil ? 0.9 : 0.3))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(themeManager.colors.textInverse.opacity(0.1))
                                .overlay(
                                    Capsule()
                                        .stroke(themeManager.colors.textInverse.opacity(0.15), lineWidth: 1)
                                )
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(content.trailerUrl == nil)
                    }
                    .opacity(showButton ? 1 : 0)
                    .offset(y: showButton ? 0 : 12)
                }
                .padding(.horizontal, DesignTokens.Spacing.horizontalPadding(hSizeClass))
                .padding(.bottom, hSizeClass == .regular ? 48 : 36)
                .frame(maxWidth: hSizeClass == .regular ? DesignTokens.maxContentWidth : .infinity, alignment: .leading)
            }
        }
        .sheet(isPresented: $showTrailer) {
            if let trailerURL = content.trailerUrl {
                PlayerTrailerModal(
                    trailerURL: trailerURL,
                    contentTitle: content.title
                )
            } else {
                ContentUnavailableView("Trailer không khả dụng", systemImage: "play.slash", description: Text("Trailer chưa được cập nhật cho nội dung này."))
            }
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                triggerStaggeredReveal()
            } else {
                resetAnimations()
            }
        }
        .onAppear {
            if isActive {
                triggerStaggeredReveal()
            }
        }
    }

    private var backdropURL: URL? {
        // iPad: prefer backdrop (16:9 landscape), iPhone: prefer poster (portrait)
        content.heroImageURL(for: hSizeClass)
    }

    private func metaChip(
        icon: String? = nil,
        text: String,
        chipColor: Color = .white,
        iconColor: Color = .white
    ) -> some View {
        HStack(spacing: 3) {
            if let icon {
                Image(systemName: icon)
                    .font(ThemeFont.body(size: 10))
                    .foregroundStyle(iconColor)
            }
            Text(text)
                .font(ThemeFont.body(size: 11, weight: .semibold))
                .foregroundStyle(ThemeColor.textPrimary.opacity(0.85))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(chipColor.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(chipColor.opacity(0.15), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // #3/#26: Single consolidated Task for stagger animation — cancellable
    private func triggerStaggeredReveal() {
        resetAnimations()
        let animation = reduceMotion
            ? Animation.easeOut(duration: 0.01)
            : Animation.easeOut(duration: 0.6)

        // Cancel any previous stagger task before starting new one
        staggerTask?.cancel()
        staggerTask = Task { @MainActor in

            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            withAnimation(animation) { showBadges = true }

            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            withAnimation(animation) { showTitle = true }

            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            withAnimation(animation) { showOriginalTitle = true }

            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            withAnimation(animation) { showMeta = true }

            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            withAnimation(animation) { showGenres = true }

            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            withAnimation(animation) { showDescription = true }

            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            withAnimation(animation) { showButton = true }
        }
    }

    private func resetAnimations() {
        // #3: Cancel in-flight stagger task
        staggerTask?.cancel()
        staggerTask = nil

        showBadges = false
        showTitle = false
        showOriginalTitle = false
        showMeta = false
        showGenres = false
        showDescription = false
        showButton = false
    }
}
