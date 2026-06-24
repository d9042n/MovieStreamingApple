//
//  WatchingHeroSliderView.swift
//  MovieStreamingApple
//
//  Cinematic hero slider for the Watching Hub — same premium quality as
//  HeroSliderView on HomeView. Auto-advancing crossfade carousel with
//  Ken Burns zoom, staggered content reveal, ambient brand glow.
//
//  Shows ALL watch history items (up to 10) sequentially.
//  Image priority: backdrop → poster fallback.
//

import SwiftUI

struct WatchingHeroSliderView: View {
    let items: [WatchDisplayData]
    let onContinue: (WatchDisplayData) -> Void
    let onDetail: (WatchDisplayData) -> Void

    @State private var currentIndex = 0
    @State private var isOnScreen = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.themeManager) private var themeManager
    @Environment(\.horizontalSizeClass) private var hSizeClass

    /// Auto-advance only runs when visible and the app is active (#10).
    private var autoAdvanceActive: Bool {
        isOnScreen && scenePhase == .active && !reduceMotion && items.count > 1
    }

    /// `currentIndex` clamped to current bounds. Reading through this avoids a blank
    /// hero / stalled auto-advance when an item is deleted and `items` shrinks below
    /// the retained `currentIndex`.
    private var safeIndex: Int {
        guard !items.isEmpty else { return 0 }
        return min(max(currentIndex, 0), items.count - 1)
    }

    var body: some View {
        if items.isEmpty {
            emptyPlaceholder
        } else {
            ZStack(alignment: .bottom) {
                // ── Crossfade carousel (PERF-01: only render adjacent slides) ──
                ZStack {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        // Only render current, previous, and next slides to reduce memory
                        if isAdjacentSlide(index) {
                            WatchingHeroSlideView(
                                item: item,
                                isActive: safeIndex == index,
                                reduceMotion: reduceMotion,
                                reverseZoom: !index.isMultiple(of: 2),
                                onContinue: { onContinue(item) },
                                onDetail: { onDetail(item) }
                            )
                            .opacity(safeIndex == index ? 1 : 0)
                        }
                    }
                }
                .aspectRatio(hSizeClass == .regular ? 16.0 / 9.0 : 2.0 / 3.0, contentMode: .fit)

                // Ambient brand glow
                ambientGlow

                // Page indicator (only if multiple)
                if items.count > 1 {
                    pageIndicator
                        .padding(.bottom, DesignTokens.Spacing.lg)
                }
            }
            // Auto-advance timer
            .task(id: "\(safeIndex)-\(autoAdvanceActive)") {
                guard autoAdvanceActive else { return }
                try? await Task.sleep(for: .seconds(9.2))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 1.2)) {
                    currentIndex = (safeIndex + 1) % items.count
                }
            }
            .onScrollVisibilityChange(threshold: 0.2) { visible in
                isOnScreen = visible
            }
            // Clamp the stored index when an item is deleted and the list shrinks.
            .onChange(of: items.count) { _, newCount in
                if currentIndex >= newCount {
                    currentIndex = max(0, newCount - 1)
                }
            }
            // Swipe gesture
            .gesture(
                DragGesture(minimumDistance: 40)
                    .onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        guard items.count > 1 else { return }
                        // ANIM-01: Use faster animation for manual swipe vs auto-advance
                        withAnimation(.easeInOut(duration: 0.5)) {
                            if value.translation.width < -50 {
                                currentIndex = (safeIndex + 1) % items.count
                            } else if value.translation.width > 50 {
                                currentIndex = (safeIndex - 1 + items.count) % items.count
                            }
                        }
                    }
            )
        }
    }

    // MARK: - Page Indicator

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            // Iterate by stable element id (not a runtime-variable Range<Int>) so
            // deleting an item doesn't trip SwiftUI's constant-range ForEach warning.
            ForEach(Array(items.enumerated()), id: \.element.id) { index, _ in
                Capsule()
                    .fill(index == safeIndex
                          ? themeManager.colors.brand
                          : themeManager.colors.textPrimary.opacity(0.3))
                    .frame(width: index == safeIndex ? 28 : 8, height: 6)
                    .shadow(
                        color: index == safeIndex
                            ? themeManager.colors.brand.opacity(0.6) : .clear,
                        radius: 6
                    )
                    .animation(reduceMotion ? .none : DesignTokens.Animation.standard, value: safeIndex)
            }
        }
        // A11Y-02: Make page indicator accessible
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Trang \(safeIndex + 1) trên \(items.count)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                withAnimation(.easeInOut(duration: 0.5)) {
                    currentIndex = (safeIndex + 1) % items.count
                }
            case .decrement:
                withAnimation(.easeInOut(duration: 0.5)) {
                    currentIndex = (safeIndex - 1 + items.count) % items.count
                }
            @unknown default:
                break
            }
        }
    }

    // MARK: - Adjacent Slide Check (PERF-01)

    /// Only return true for current, previous, and next slide indices (wrapping).
    private func isAdjacentSlide(_ index: Int) -> Bool {
        guard items.count > 2 else { return true }
        let prev = (safeIndex - 1 + items.count) % items.count
        let next = (safeIndex + 1) % items.count
        return index == safeIndex || index == prev || index == next
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

    // MARK: - Empty Placeholder

    private var emptyPlaceholder: some View {
        Rectangle()
            .fill(ThemeColor.bgCard)
            .aspectRatio(hSizeClass == .regular ? 16.0 / 9.0 : 2.0 / 3.0, contentMode: .fit)
            .overlay {
                VStack(spacing: DesignTokens.Spacing.md) {
                    Image(systemName: AppIcon.playCircle)
                        .font(ThemeFont.display(size: 40))
                        .foregroundStyle(themeManager.colors.textMuted)
                    Text("Đang tải...")
                        .font(ThemeFont.body(size: 12))
                        .foregroundStyle(themeManager.colors.textMuted)
                        .textCase(.uppercase)
                }
            }
    }
}

// MARK: - Individual Slide (Cinematic — matches HeroSlideView quality)

private struct WatchingHeroSlideView: View {
    let item: WatchDisplayData
    let isActive: Bool
    let reduceMotion: Bool
    let reverseZoom: Bool
    let onContinue: () -> Void
    let onDetail: () -> Void

    @Environment(\.themeManager) private var themeManager
    @Environment(\.horizontalSizeClass) private var hSizeClass

    // Staggered animation states
    @State private var showBadge = false
    @State private var showTitle = false
    @State private var showMeta = false
    @State private var showProgress = false
    @State private var showButtons = false
    @State private var staggerTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                // ── LAYER 1: Full-bleed backdrop image ──
                CachedAsyncImage(url: item.heroImageUrl(for: hSizeClass)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .kenBurns(
                            isActive: isActive,
                            maxScale: 1.10,
                            duration: 8.0,
                            reverse: reverseZoom,
                            repeats: false,
                            startDelay: 1.2
                        )
                        .clipped()
                } placeholder: {
                    Rectangle()
                        .fill(ThemeColor.bgCard)
                        .overlay { ProgressView().tint(themeManager.colors.brand.opacity(0.3)) }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()

                // ── LAYER 2: Bottom gradient ──
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: ThemeColor.bgBase.opacity(0.08), location: 0.35),
                        .init(color: ThemeColor.bgBase.opacity(0.4), location: 0.55),
                        .init(color: ThemeColor.bgBase.opacity(0.8), location: 0.75),
                        .init(color: ThemeColor.bgBase.opacity(0.95), location: 0.9),
                        .init(color: ThemeColor.bgBase, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Top gradient (Dynamic Island blend)
                VStack {
                    LinearGradient(
                        stops: [
                            .init(color: ThemeColor.bgBase.opacity(0.7), location: 0.0),
                            .init(color: ThemeColor.bgBase.opacity(0.35), location: 0.5),
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

                    // Badge: "Watching" or "Finished"
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Label(
                            item.entry.isFinished ? "Đã Xem Xong" : "Đang Xem",
                            systemImage: item.entry.isFinished ? AppIcon.checkmark : AppIcon.playFill
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
                            item.entry.contentType == .series ? "TV Series" : "Phim Lẻ",
                            systemImage: item.entry.contentType == .series ? AppIcon.tv : AppIcon.film
                        )
                        .font(ThemeFont.display(size: 11, weight: .medium))
                        .foregroundStyle(themeManager.colors.textPrimary)
                    }
                    .padding(.bottom, 8)
                    .opacity(showBadge ? 1 : 0)
                    .offset(y: showBadge ? 0 : 12)

                    // Title
                    Text(item.title)
                        .font(ThemeFont.display(size: 26, weight: .heavy))
                        .foregroundStyle(themeManager.colors.textInverse)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 66)
                        .shadow(color: ThemeColor.bgBase.opacity(0.7), radius: 10, y: 3)
                        .opacity(showTitle ? 1 : 0)
                        .offset(y: showTitle ? 0 : 14)

                    // Meta chips (episode info, remaining time, progress %)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            if item.entry.contentType == .series {
                                if let sn = item.entry.seasonNumber {
                                    metaChip(text: "Phần \(sn)")
                                }
                                if let ep = item.entry.episodeNumber {
                                    metaChip(text: "Tập \(ep)")
                                }
                            }

                            if !item.entry.isFinished {
                                metaChip(
                                    icon: AppIcon.playCircle,
                                    text: "\(Int(item.entry.progress * 100))%",
                                    chipColor: themeManager.colors.brand,
                                    iconColor: themeManager.colors.brand
                                )
                            }

                            if let remaining = item.remainingTimeFormatted {
                                metaChip(icon: AppIcon.clock, text: remaining)
                            }

                            if let mins = item.durationMinutes {
                                let h = mins / 60
                                let m = mins % 60
                                metaChip(
                                    icon: AppIcon.clock,
                                    text: h > 0 ? "\(h)h \(m)m" : "\(m) phút"
                                )
                            }
                        }
                    }
                    .frame(height: 28)
                    .padding(.bottom, 8)
                    .opacity(showMeta ? 1 : 0)
                    .offset(y: showMeta ? 0 : 10)

                    // Progress bar
                    Group {
                        if item.entry.progress > 0.01 && !item.entry.isFinished {
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(themeManager.colors.textPrimary.opacity(0.15))
                                    .frame(height: 5)

                                GeometryReader { barGeo in
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(
                                            LinearGradient(
                                                colors: [themeManager.colors.brand, themeManager.colors.brandHover],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: barGeo.size.width * item.entry.progress, height: 5)
                                }
                            }
                            .frame(height: 5)
                        } else {
                            Color.clear.frame(height: 5)
                        }
                    }
                    .padding(.bottom, 12)
                    .opacity(showProgress ? 1 : 0)
                    .offset(y: showProgress ? 0 : 8)

                    // Action buttons
                    HStack(spacing: DesignTokens.Spacing.md) {
                        Button(action: onContinue) {
                            Label(
                                item.entry.isFinished ? "Xem Lại" : "Xem Tiếp",
                                systemImage: AppIcon.playFill
                            )
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

                        Button(action: onDetail) {
                            Label("Chi Tiết", systemImage: AppIcon.textPage)
                                .font(ThemeFont.display(size: 14, weight: .bold))
                                .foregroundStyle(themeManager.colors.textInverse.opacity(0.9))
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
                    }
                    .opacity(showButtons ? 1 : 0)
                    .offset(y: showButtons ? 0 : 12)
                }
                .padding(.horizontal, DesignTokens.Spacing.horizontalPadding(hSizeClass))
                .padding(.bottom, hSizeClass == .regular ? 48 : 36)
                .frame(maxWidth: hSizeClass == .regular ? DesignTokens.maxContentWidth : .infinity, alignment: .leading)
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

    // MARK: - Meta Chip (same style as HeroSliderView)

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
                .foregroundStyle(themeManager.colors.textPrimary.opacity(0.85))
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

    // MARK: - Staggered Reveal (same pattern as HeroSlideView)

    private func triggerStaggeredReveal() {
        resetAnimations()
        let animation = reduceMotion
            ? Animation.easeOut(duration: 0.01)
            : Animation.easeOut(duration: 0.6)

        staggerTask?.cancel()
        staggerTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            withAnimation(animation) { showBadge = true }

            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            withAnimation(animation) { showTitle = true }

            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            withAnimation(animation) { showMeta = true }

            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            withAnimation(animation) { showProgress = true }

            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            withAnimation(animation) { showButtons = true }
        }
    }

    private func resetAnimations() {
        staggerTask?.cancel()
        staggerTask = nil
        showBadge = false
        showTitle = false
        showMeta = false
        showProgress = false
        showButtons = false
    }
}
