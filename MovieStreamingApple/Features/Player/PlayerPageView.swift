//
//  PlayerPageView.swift
//  MovieStreamingApple
//
//  Main Watch page composing: VideoPlayer + ServerSelector + ContentInfo +
//  EpisodeList + ActionBar + Cast + MediaGallery + Related.
//  Handles both Movie and Series in a single view.
//  Full feature parity with web: embed fallback, trailer modal,
//  media lightbox, settings sheet, auto-play next episode.
//
//  Redesigned with Netflix/YouTube-inspired layout for premium feel.
//

import SwiftUI
import UIKit

struct PlayerPageView: View {
    let slug: String
    let contentType: ContentType
    var episodeId: String?
    var seasonNumber: Int?
    var episodeNumber: Int?
    var autoResume: Bool = false

    @State private var viewModel = PlayerPageViewModel()
    @State private var playerVM = VideoPlayerViewModel()
    @State private var isEpisodeListVisible = false
    @State private var showSettings = false
    @State private var showTrailer = false
    /// Portrait fullscreen state for vertical content (short drama)
    @State private var isVerticalFullScreen = false
    /// Manual fullscreen state (solves iPad restricted programmatic layout updates)
    @State private var isManualFullscreen = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeManager) private var themeManager
    @Environment(WatchHistoryManager.self) private var watchHistory
    @Environment(AppRouter.self) private var router
    @Environment(\.horizontalSizeClass) private var hSizeClass
    
    @AppStorage("useMathTransformFullscreen") private var useMathTransformFullscreen = false

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            let topInset = geometry.safeAreaInsets.top

            if viewModel.isLoading && viewModel.content == nil {
                loadingView
            } else if let error = viewModel.error, viewModel.content == nil {
                errorView(error)
            } else if viewModel.isVerticalContent {
                // Vertical short drama: portrait-locked layout
                verticalContentLayout(screenSize: geometry.size)
            } else {
                let isFullscreen = isLandscape || isManualFullscreen

                if isFullscreen {
                    let isVerticalLockOnIPad = isManualFullscreen && !isLandscape && UIDevice.current.userInterfaceIdiom == .pad
                    
                    if isVerticalLockOnIPad && useMathTransformFullscreen && hSizeClass != .compact {
                        // Apply Math Transform Hack to bypass iPadOS rotation constraints
                        mathTransformLandscapeLayout(physicalSize: geometry.size)
                    } else {
                        // Standard layout (either naturally landscape or normal manual scale)
                        landscapeLayout
                    }
                } else {
                    portraitLayout(topInset: topInset)
                }
            }
        }
        .background(ThemeColor.bgBase.ignoresSafeArea())
        .toolbarVisibility(.hidden, for: .navigationBar)
        .toolbarVisibility(.hidden, for: .tabBar)
        .persistentSystemOverlays(.hidden)

        .task {
            await viewModel.loadContent(
                slug: slug,
                type: contentType,
                episodeId: episodeId,
                seasonNumber: seasonNumber,
                episodeNumber: episodeNumber
            )
        }
        // Lock orientation to portrait for vertical content
        .onChange(of: viewModel.isVerticalContent) { _, isVertical in
            if isVertical { lockPortrait() }
        }
        .onChange(of: viewModel.videoSource) { _, newSource in
            loadPlayerSource(url: newSource)
        }
        // #52: Removed duplicate onChange(of: activeServerIndex) — videoSource is
        // derived from activeServerIndex, so the onChange above already handles it.
        .onAppear {
            router.isPlayerActive = true
            // iPhone: allow landscape while player is active
            if UIDevice.current.userInterfaceIdiom == .phone {
                AppDelegate.allowLandscapeOnPhone = true
            }
            // Restore player source if it was cleaned up during onDisappear
            // but the viewModel still has valid data (e.g., user navigated
            // forward to ContentDetail/PersonDetail then popped back).
            // .task doesn't re-fire and .onChange(of: videoSource) doesn't
            // trigger because the value hasn't changed — so we must reload here.
            if !viewModel.isEmbed,
               playerVM.needsReload,
               !viewModel.videoSource.isEmpty {
                loadPlayerSource(url: viewModel.videoSource)
            }
        }
        .onDisappear {
            router.isPlayerActive = false
            saveToWatchHistory()
            playerVM.cleanup()
            // iPhone: revoke landscape permission and force back to portrait
            if UIDevice.current.userInterfaceIdiom == .phone {
                AppDelegate.allowLandscapeOnPhone = false
                forcePortraitOnPhone()
            }
        }
        .sheet(isPresented: $showSettings) {
            PlayerSettingsSheet(
                playerVM: playerVM,
                subtitles: viewModel.subtitles,
                servers: viewModel.servers,
                activeServerIndex: viewModel.activeServerIndex,
                onServerChange: { index in
                    viewModel.selectServer(at: index)
                }
            )
        }
        .sheet(isPresented: $showTrailer) {
            if let trailerURL = viewModel.content?.trailerUrl {
                PlayerTrailerModal(
                    trailerURL: trailerURL,
                    contentTitle: viewModel.content?.title ?? ""
                )
            }
        }
        .onChange(of: showTrailer) { _, isShowing in
            if isShowing {
                playerVM.pause()
            }
        }
        // Value-based navigation destinations for sub-components
        .navigationDestination(for: PersonDestination.self) { dest in
            PersonDetailView(slug: dest.slug)
        }
        .navigationDestination(for: ContentDestination.self) { dest in
            ContentDetailView(slug: dest.slug, contentType: dest.type)
        }
    }

    // MARK: - Portrait Layout (matches web WatchPage mobile layout)

    private func portraitLayout(topInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Player (16:9 aspect ratio) — sits below Dynamic Island.
            // Same safe area pattern as verticalNonFullscreenLayout.
            playerSection
                .aspectRatio(16/9, contentMode: .fit)

            // Scrollable content below
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // === Section: Mobile Episode Toggle (series only, like web) ===
                    if viewModel.isSeries {
                        episodeListToggle
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 6)

                        // Collapsible episode panel
                        if isEpisodeListVisible {
                            VStack(spacing: 0) {
                                // Season selector (when multiple seasons)
                                if viewModel.seasons.count > 1 {
                                    seasonSelectorRow
                                }

                                PlayerEpisodeList(
                                    seasons: viewModel.seasons,
                                    activeSeasonId: viewModel.activeSeasonId,
                                    episodes: viewModel.seasonEpisodes,
                                    currentEpisodeId: viewModel.currentEpisode?.id,
                                    posterFallback: viewModel.content?.posterUrl,
                                    isLoading: viewModel.isEpisodesLoading,
                                    showHeader: false,
                                    onSeasonChange: { seasonId in
                                        Task {
                                            await viewModel.changeSeason(to: seasonId, slug: slug)
                                        }
                                    },
                                    onEpisodeTap: { episodeId in
                                        viewModel.goToEpisode(episodeId)
                                        withAnimation { isEpisodeListVisible = false }
                                    }
                                )
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 6)
                            .transition(.opacity)
                        }
                    }

                    // === Section: Server selector ===
                    PlayerServerSelector(
                        servers: viewModel.servers,
                        activeIndex: viewModel.activeServerIndex
                    ) { index in
                        viewModel.selectServer(at: index)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, viewModel.isSeries ? 6 : 14)
                    .padding(.bottom, 10)

                    // === Section: Title + Meta Row ===
                    PlayerContentInfo(
                        content: viewModel.content,
                        displayTitle: viewModel.displayTitle,
                        displayDescription: viewModel.displayDescription,
                        isSeries: viewModel.isSeries,
                        currentEpisode: viewModel.currentEpisode,
                        directors: viewModel.directors,
                        actors: viewModel.actors,
                        bookmarkCount: viewModel.content?.stats?.bookmarkCount
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)

                    // === Section: Action bar ===
                    PlayerActionBar(
                        content: viewModel.content,
                        nextEpisode: viewModel.nextEpisode,
                        isSeries: viewModel.isSeries,
                        bookmarkCount: viewModel.content?.stats?.bookmarkCount,
                        onShare: { shareContent() },
                        onNextEpisode: { goToNextEpisode() }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                    // Separator
                    sectionDivider

                    // === Section: Media gallery ===
                    if !viewModel.media.isEmpty || viewModel.content?.trailerUrl != nil {
                        PlayerMediaGallery(
                            media: viewModel.media,
                            trailerURL: viewModel.content?.trailerUrl,
                            contentTitle: viewModel.content?.title ?? ""
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        sectionDivider
                    }

                    // === Section: Related content ===
                    if !viewModel.relatedContents.isEmpty {
                        PlayerRelatedGrid(
                            contents: viewModel.relatedContents
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }

                    // Bottom safe area spacing
                    Color.clear.frame(height: 50)
                }
            }
        }
    }

    // Subtle section divider
    private var sectionDivider: some View {
        Rectangle()
            .fill(themeManager.colors.border)
            .frame(height: 0.5)
            .padding(.horizontal, 16)
    }

    // Mobile episode list toggle (matches web's collapsible pattern)
    private var episodeListToggle: some View {
        Button {
            withAnimation(DesignTokens.Animation.standard) {
                isEpisodeListVisible.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: AppIcon.listBulletRectanglePortrait)
                    .font(ThemeFont.body(size: 14, weight: .semibold))
                    .foregroundStyle(themeManager.colors.link)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Danh sách tập")
                        .font(ThemeFont.body(size: 14, weight: .bold))
                        .foregroundStyle(ThemeColor.textPrimary)

                    // Show active season name when multiple seasons
                    if viewModel.seasons.count > 1,
                       let activeSeason = viewModel.activeSeason {
                        Text(activeSeason.title)
                            .font(ThemeFont.body(size: 11))
                            .foregroundStyle(ThemeColor.textMuted)
                            .lineLimit(1)
                    }
                }

                if let ep = viewModel.currentEpisode, let epNum = ep.episodeNumber {
                    Text("Tập \(epNum)")
                        .font(ThemeFont.display(size: 11, weight: .bold))
                        .foregroundStyle(ThemeColor.textPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(themeManager.colors.brand, in: Capsule())
                }

                Spacer()

                Image(systemName: AppIcon.chevronDown)
                    .font(ThemeFont.body(size: 13, weight: .medium))
                    .foregroundStyle(ThemeColor.textMuted)
                    .rotationEffect(.degrees(isEpisodeListVisible ? 180 : 0))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(themeManager.colors.bgCard, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Season Selector Row

    /// Horizontal scrollable season pills — shown inside the expanded episode panel.
    private var seasonSelectorRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.seasons) { season in
                    let isActive = season.id == viewModel.activeSeasonId

                    Button {
                        Task {
                            await viewModel.changeSeason(to: season.id, slug: slug)
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(season.title)
                                .font(ThemeFont.body(size: 12, weight: isActive ? .bold : .medium))
                                .foregroundStyle(isActive ? .white : .secondary)

                            if let count = season.episodeCount {
                                Text("(\(count))")
                                    .font(ThemeFont.body(size: 10))
                                    .foregroundStyle(isActive ? ThemeColor.textPrimary.opacity(0.7) : Color.secondary.opacity(0.6))
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            isActive
                                ? themeManager.colors.brand
                                : themeManager.colors.bgCard,
                            in: Capsule()
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    isActive
                                        ? Color.clear
                                        : ThemeColor.textPrimary.opacity(0.08),
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Vertical Content Layout (Short Drama — Portrait-locked)

    /// Layout for vertical short dramas (9:16 content).
    /// Two modes: non-fullscreen (player + info) and fullscreen (immersive portrait).
    @ViewBuilder
    private func verticalContentLayout(screenSize: CGSize) -> some View {
        if isVerticalFullScreen {
            verticalFullscreenLayout(screenSize: screenSize)
        } else {
            verticalNonFullscreenLayout(screenSize: screenSize)
        }
    }

    /// Vertical fullscreen: player fills entire screen in portrait, overlay controls.
    /// Matches TikTok / YouTube Shorts immersive experience.
    /// Video renders edge-to-edge via internal .ignoresSafeArea() on ThemeColor.bgBase + AVPlayerLayerView.
    /// HUD buttons stay within safe area (below Dynamic Island, above home indicator).
    private func verticalFullscreenLayout(screenSize: CGSize) -> some View {
        ZStack {
            playerSection

            // Episode list overlay (series, toggled) — same pattern as landscape
            if viewModel.isSeries && isEpisodeListVisible {
                // Dark scrim — tap to close
                ThemeColor.bgBase.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(DesignTokens.Animation.standard) {
                            isEpisodeListVisible = false
                        }
                    }

                HStack {
                    Spacer()

                    PlayerEpisodeList(
                        seasons: viewModel.seasons,
                        activeSeasonId: viewModel.activeSeasonId,
                        episodes: viewModel.seasonEpisodes,
                        currentEpisodeId: viewModel.currentEpisode?.id,
                        posterFallback: viewModel.content?.posterUrl,
                        isLoading: viewModel.isEpisodesLoading,
                        onSeasonChange: { seasonId in
                            Task {
                                await viewModel.changeSeason(to: seasonId, slug: slug)
                            }
                        },
                        onEpisodeTap: { episodeId in
                            viewModel.goToEpisode(episodeId)
                            withAnimation { isEpisodeListVisible = false }
                        }
                    )
                    .frame(width: min(320, screenSize.width * 0.85))
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.vertical, 8)
                    .padding(.trailing, 8)
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .animation(DesignTokens.Animation.standard, value: isEpisodeListVisible)
            }
        }
    }

    /// Vertical non-fullscreen: large player (~65%) + compact scrollable info below.
    private func verticalNonFullscreenLayout(screenSize: CGSize) -> some View {
        let playerHeight = screenSize.height * 0.6

        return VStack(spacing: 0) {
            // Player with 9:16 aspect ratio, capped at ~60% screen height
            playerSection
                .frame(height: playerHeight)
                .clipped()

            // Compact scrollable content below
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // === Section: Compact Episode Toggle (series only) ===
                    if viewModel.isSeries {
                        episodeListToggle
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                            .padding(.bottom, 4)

                        // Collapsible episode panel
                        if isEpisodeListVisible {
                            VStack(spacing: 0) {
                                // Season selector (when multiple seasons)
                                if viewModel.seasons.count > 1 {
                                    seasonSelectorRow
                                }

                                PlayerEpisodeList(
                                    seasons: viewModel.seasons,
                                    activeSeasonId: viewModel.activeSeasonId,
                                    episodes: viewModel.seasonEpisodes,
                                    currentEpisodeId: viewModel.currentEpisode?.id,
                                    posterFallback: viewModel.content?.posterUrl,
                                    isLoading: viewModel.isEpisodesLoading,
                                    showHeader: false,
                                    onSeasonChange: { seasonId in
                                        Task {
                                            await viewModel.changeSeason(to: seasonId, slug: slug)
                                        }
                                    },
                                    onEpisodeTap: { episodeId in
                                        viewModel.goToEpisode(episodeId)
                                        withAnimation { isEpisodeListVisible = false }
                                    }
                                )
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 4)
                            .transition(.opacity)
                        }
                    }

                    // === Section: Server selector ===
                    PlayerServerSelector(
                        servers: viewModel.servers,
                        activeIndex: viewModel.activeServerIndex
                    ) { index in
                        viewModel.selectServer(at: index)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, viewModel.isSeries ? 4 : 10)
                    .padding(.bottom, 8)

                    // === Section: Title + Meta Row ===
                    PlayerContentInfo(
                        content: viewModel.content,
                        displayTitle: viewModel.displayTitle,
                        displayDescription: viewModel.displayDescription,
                        isSeries: viewModel.isSeries,
                        currentEpisode: viewModel.currentEpisode,
                        directors: viewModel.directors,
                        actors: viewModel.actors,
                        bookmarkCount: viewModel.content?.stats?.bookmarkCount
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                    // === Section: Action bar ===
                    PlayerActionBar(
                        content: viewModel.content,
                        nextEpisode: viewModel.nextEpisode,
                        isSeries: viewModel.isSeries,
                        bookmarkCount: viewModel.content?.stats?.bookmarkCount,
                        onShare: { shareContent() },
                        onNextEpisode: { goToNextEpisode() }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                    sectionDivider

                    // === Section: Related content ===
                    if !viewModel.relatedContents.isEmpty {
                        PlayerRelatedGrid(
                            contents: viewModel.relatedContents
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }

                    // Bottom safe area spacing
                    Color.clear.frame(height: 50)
                }
            }
        }
    }

    // MARK: - Landscape Layout

    private var landscapeLayout: some View {
        ZStack {
            playerSection
                .ignoresSafeArea()

            // Episode list overlay (series, toggled) with scrim + close
            if viewModel.isSeries && isEpisodeListVisible {
                // Dark scrim — tap to close
                ThemeColor.bgBase.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(DesignTokens.Animation.standard) {
                            isEpisodeListVisible = false
                        }
                    }

                HStack {
                    Spacer()

                    PlayerEpisodeList(
                        seasons: viewModel.seasons,
                        activeSeasonId: viewModel.activeSeasonId,
                        episodes: viewModel.seasonEpisodes,
                        currentEpisodeId: viewModel.currentEpisode?.id,
                        posterFallback: viewModel.content?.posterUrl,
                        isLoading: viewModel.isEpisodesLoading,
                        onSeasonChange: { seasonId in
                            Task {
                                await viewModel.changeSeason(to: seasonId, slug: slug)
                            }
                        },
                        onEpisodeTap: { episodeId in
                            viewModel.goToEpisode(episodeId)
                            withAnimation { isEpisodeListVisible = false }
                        }
                    )
                    .frame(width: 320)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.vertical, 8)
                    .padding(.trailing, 8)
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .animation(DesignTokens.Animation.standard, value: isEpisodeListVisible)
            }
        }
    }

    // MARK: - Landscape Math Transform Layout (iPad Only)
    
    /// Bypasses iPadOS multitasking locks by using 90-degree visual rotation and frame swapping.
    /// Used when 'useMathTransformFullscreen' is enabled and the iPad is stuck in portrait.
    private func mathTransformLandscapeLayout(physicalSize: CGSize) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Standard landscape layout, but constrained and rotated
            landscapeLayout
                // 1. Swap width and height to match the sideways screen
                .frame(width: physicalSize.height, height: physicalSize.width)
                
                // 2. Rotate it visually 90 degrees clockwise
                .rotationEffect(.degrees(90))
                
                // 3. Pin it exactly to the center of the vertical screen to prevent drifting
                .position(x: physicalSize.width / 2, y: physicalSize.height / 2)
        }
        .ignoresSafeArea(.all)
        .statusBarHidden(true)
    }

    // MARK: - Player Section

    @ViewBuilder
    private var playerSection: some View {
        if viewModel.isEmbed {
            // Embed player (WKWebView) for servers without HLS
            EmbedPlayerContainerView(
                embedURL: viewModel.embedSource,
                title: viewModel.displayTitle,
                onBack: { handleBack() }
            )
        } else {
            // Native HLS player
            VideoPlayerView(
                viewModel: playerVM,
                title: viewModel.displayTitle,
                subtitle: viewModel.content?.originalTitle,
                hasPrevious: viewModel.previousEpisode != nil,
                hasNext: viewModel.nextEpisode != nil,
                isSeries: viewModel.isSeries,
                isEpisodeListVisible: isEpisodeListVisible,
                isVerticalContent: viewModel.isVerticalContent,
                isVerticalFullScreen: isVerticalFullScreen,
                onToggleVerticalFullscreen: {
                    withAnimation(DesignTokens.Animation.standard) {
                        isVerticalFullScreen.toggle()
                    }
                },
                isManualFullscreen: isManualFullscreen,
                onToggleManualFullscreen: {
                    withAnimation(DesignTokens.Animation.standard) {
                        isManualFullscreen.toggle()
                    }
                },
                onBack: {
                    handleBack()
                },
                onPrevious: {
                    goToPreviousEpisode()
                },
                onNext: {
                    goToNextEpisode()
                },
                onEpisodeList: {
                    withAnimation {
                        isEpisodeListVisible.toggle()
                    }
                },
                onSettings: {
                    showSettings = true
                }
            )
            .onAppear {
                // Setup auto-play next callback.
                // Note: In SwiftUI struct views, closures capture `self` value-type
                // but @State references are stable. Reading viewModel properties
                // inside the closure always gets fresh state.
                playerVM.onPlaybackFinished = { [viewModel] in
                    if viewModel.isSeries, viewModel.nextEpisode != nil {
                        goToNextEpisode()
                    }
                }
                // Setup error retry: try next server
                playerVM.onError = { [viewModel] in
                    viewModel.tryNextServer()
                }
                // Lock portrait for vertical content on appear
                if viewModel.isVerticalContent {
                    lockPortrait()
                }
            }
        }
    }

    // MARK: - Loading (Skeleton)

    private var loadingView: some View {
        VStack(spacing: 0) {
            // Player skeleton
            Rectangle()
                .fill(themeManager.colors.bgCard)
                .aspectRatio(16/9, contentMode: .fit)
                .overlay {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(.white.opacity(0.6))
                        Text("Đang tải...")
                            .font(ThemeFont.body(size: 12))
                            .foregroundStyle(ThemeColor.textPrimary.opacity(0.4))
                    }
                }

            // Content skeleton below
            VStack(alignment: .leading, spacing: 14) {
                // Server chips skeleton
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 10)
                            .fill(themeManager.colors.bgCard)
                            .frame(width: 80, height: 34)
                    }
                }

                // Title skeleton
                RoundedRectangle(cornerRadius: 4)
                    .fill(themeManager.colors.bgCard)
                    .frame(height: 22)
                    .frame(maxWidth: 260)

                // Meta skeleton
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 6)
                            .fill(themeManager.colors.bgCard)
                            .frame(width: 56, height: 22)
                    }
                }

                // Description skeleton
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(0..<2, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(themeManager.colors.bgCard.opacity(0.7))
                            .frame(height: 14)
                    }
                    RoundedRectangle(cornerRadius: 3)
                        .fill(themeManager.colors.bgCard.opacity(0.5))
                        .frame(height: 14)
                        .frame(maxWidth: 200)
                }

                // Action bar skeleton
                HStack {
                    ForEach(0..<3, id: \.self) { _ in
                        VStack(spacing: 6) {
                            Circle()
                                .fill(themeManager.colors.bgCard)
                                .frame(width: 28, height: 28)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(themeManager.colors.bgCard)
                                .frame(width: 40, height: 10)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ThemeColor.bgBase)
        .shimmer()
    }

    // MARK: - Error

    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 0) {
            // Dark player area
            Rectangle()
                .fill(ThemeColor.bgBase)
                .aspectRatio(16/9, contentMode: .fit)
                .overlay {
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.05))
                                .frame(width: 72, height: 72)
                            Image(systemName: AppIcon.exclamationmarkTriangle)
                                .font(ThemeFont.display(size: 28))
                                .foregroundStyle(ThemeColor.textMuted)
                        }

                        Text("Không thể tải nội dung")
                            .font(ThemeFont.body(size: 14, weight: .semibold))
                            .foregroundStyle(ThemeColor.textPrimary.opacity(0.8))

                        Text(message)
                            .font(ThemeFont.body(size: 12))
                            .foregroundStyle(ThemeColor.textPrimary.opacity(0.4))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }

            // Actions below
            VStack(spacing: 12) {
                // Retry
                Button {
                    Task {
                        await viewModel.loadContent(
                            slug: slug,
                            type: contentType,
                            episodeId: episodeId,
                            seasonNumber: seasonNumber,
                            episodeNumber: episodeNumber
                        )
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: AppIcon.arrowClockwise)
                            .font(ThemeFont.body(size: 14, weight: .bold))
                        Text("Thử lại")
                            .font(ThemeFont.body(size: 14, weight: .bold))
                    }
                    .foregroundStyle(ThemeColor.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(themeManager.colors.brand, in: RoundedRectangle(cornerRadius: 10))
                }

                // Back
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: AppIcon.chevronLeft)
                            .font(ThemeFont.body(size: 14))
                        Text("Quay lại")
                            .font(ThemeFont.body(size: 14))
                    }
                    .foregroundStyle(ThemeColor.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(themeManager.colors.bgCard, in: RoundedRectangle(cornerRadius: 10))
                }

                // Trailer fallback
                if viewModel.content?.trailerUrl != nil {
                    Button {
                        showTrailer = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: AppIcon.playRectangle)
                                .font(ThemeFont.body(size: 14))
                            Text("Xem Trailer")
                                .font(ThemeFont.body(size: 14, weight: .medium))
                        }
                        .foregroundStyle(themeManager.colors.link)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ThemeColor.bgBase)
    }

    // MARK: - Player Source Loading

    private func loadPlayerSource(url: String) {
        guard !url.isEmpty else { return }
        
        // Look up saved resume position from unified WatchHistoryManager
        let entry = watchHistory.entries.first(where: { $0.slug == slug })
        let targetEpisodeId = viewModel.currentEpisode?.id ?? episodeId
        let isSameEpisode = entry?.currentEpisodeId == targetEpisodeId
        
        let resumePos: TimeInterval?
        if let entry = entry, isSameEpisode, !entry.isFinished {
            resumePos = entry.resumePositionSeconds
        } else {
            resumePos = nil
        }
        
        playerVM.loadSource(
            url: url,
            subtitles: viewModel.subtitles,
            poster: viewModel.posterUrl,
            autoPlay: true,
            movieId: slug,
            episodeId: targetEpisodeId,
            resumePosition: resumePos,
            autoResume: autoResume
        )
    }

    // MARK: - Orientation

    /// Smart back:
    /// - Vertical content fullscreen → exit fullscreen only
    /// - Landscape → exit fullscreen (rotate to portrait) only
    /// - Portrait → dismiss view
    private func handleBack() {
        // Vertical content: exit fullscreen first
        if viewModel.isVerticalContent && isVerticalFullScreen {
            withAnimation(DesignTokens.Animation.standard) {
                isVerticalFullScreen = false
            }
            return
        }

        if isManualFullscreen {
            withAnimation(DesignTokens.Animation.standard) {
                isManualFullscreen = false
            }
            return
        }

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           windowScene.interfaceOrientation.isLandscape {
            // Just exit fullscreen (rotate to portrait), don't dismiss
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
            windowScene.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        } else {
            // Leaving player entirely — revoke landscape on iPhone
            if UIDevice.current.userInterfaceIdiom == .phone {
                AppDelegate.allowLandscapeOnPhone = false
                forcePortraitOnPhone()
            }
            dismiss()
        }
    }

    /// Lock device orientation to portrait only.
    private func lockPortrait() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
        windowScene.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
    }

    /// Force iPhone back to portrait and notify the system.
    private func forcePortraitOnPhone() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
        windowScene.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
    }

    // MARK: - Episode Navigation

    private func goToNextEpisode() {
        viewModel.goToNextEpisode()
    }

    private func goToPreviousEpisode() {
        viewModel.goToPreviousEpisode()
    }

    // MARK: - Share

    private func shareContent() {
        guard let content = viewModel.content else { return }
        let typePrefix = contentType == .series ? "tv" : "movie"
        // #5: Guard against nil URL
        guard let shareURL = URL(string: "https://d9042n.online/watch/\(typePrefix)/\(content.effectiveSlug)") else {
            return
        }

        let activityVC = UIActivityViewController(
            activityItems: [content.title, shareURL],
            applicationActivities: nil
        )

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }

        // For iPad
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = rootVC.view
            popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        rootVC.present(activityVC, animated: true)
    }

    // MARK: - Watch History Integration

    /// Save current content + progress to WatchHistoryManager.
    /// Called when WatchView disappears.
    private func saveToWatchHistory() {
        guard let content = viewModel.content else { return }
        // Only save if we actually started watching (progress > 0)
        guard playerVM.currentTime > 0 else { return }

        let progress: Double
        if playerVM.duration > 0 {
            progress = playerVM.currentTime / playerVM.duration
        } else {
            progress = 0
        }

        watchHistory.addOrUpdate(
            slug: content.effectiveSlug,
            contentType: contentType,
            progress: progress,
            resumePosition: playerVM.currentTime,
            seasonNumber: viewModel.activeSeason?.seasonNumber,
            episodeNumber: viewModel.currentEpisode?.episodeNumber,
            episodeId: viewModel.currentEpisode?.id
        )
    }
}
