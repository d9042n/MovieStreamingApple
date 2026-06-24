//
//  PlayerMediaGallery.swift
//  MovieStreamingApple
//
//  Media gallery with backdrop/poster thumbnails, trailer card, and lightbox.
//  Mirrors web's H1-H5 features.
//

import SwiftUI

struct PlayerMediaGallery: View {
    let media: [MediaItem]
    let trailerURL: String?
    let contentTitle: String

    @State private var selectedImageURL: String?
    @State private var selectedImageIndex: Int = 0
    @State private var showLightbox = false
    @State private var showTrailer = false

    @Environment(\.themeManager) private var themeManager

    private var backdrops: [MediaItem] {
        media.filter { $0.isBackdrop }
    }

    private var posters: [MediaItem] {
        media.filter { $0.isPoster }
    }

    private var allImages: [MediaItem] {
        backdrops + posters
    }

    var body: some View {
        if !media.isEmpty || trailerURL != nil {
            VStack(alignment: .leading, spacing: 16) {
                // Backdrops section
                if !backdrops.isEmpty || trailerURL != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        sectionHeader(icon: AppIcon.photoOnRectangle, title: "Hình ảnh")

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                // Trailer card (if available)
                                if let trailer = trailerURL {
                                    trailerCard(trailer)
                                }

                                // Backdrops
                                ForEach(Array(backdrops.enumerated()), id: \.element.id) { index, item in
                                    mediaImageCard(item, index: index, width: 200, height: 112)
                                }
                            }
                        }
                    }
                }

                // Posters section
                if !posters.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        sectionHeader(icon: AppIcon.rectanglePortrait, title: "Poster")

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(Array(posters.enumerated()), id: \.element.id) { index, item in
                                    mediaImageCard(item, index: backdrops.count + index, width: 100, height: 150)
                                }
                            }
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showLightbox) {
                MediaLightboxView(
                    images: allImages,
                    selectedIndex: $selectedImageIndex
                )
            }
            .sheet(isPresented: $showTrailer) {
                if let trailer = trailerURL {
                    PlayerTrailerModal(trailerURL: trailer, contentTitle: contentTitle)
                }
            }
        }
    }

    // MARK: - Section Header

    @ViewBuilder
    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(ThemeFont.body(size: 11))
                .foregroundStyle(themeManager.colors.brand)
            Text(title)
                .font(ThemeFont.display(size: 14, weight: .bold))
                .textCase(.uppercase)
                .foregroundStyle(ThemeColor.textMuted)
        }
    }

    // MARK: - Trailer Card

    @ViewBuilder
    private func trailerCard(_ url: String) -> some View {
        Button {
            showTrailer = true
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(
                        colors: [themeManager.colors.brand.opacity(0.3), .black.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 200, height: 112)

                VStack(spacing: 8) {
                    Image(systemName: AppIcon.playCircleFill)
                        .font(ThemeFont.display(size: 36))
                        .foregroundStyle(themeManager.colors.brand)

                        Text("Trailer chính thức")
                            .font(ThemeFont.display(size: 12, weight: .bold))
                            .foregroundStyle(ThemeColor.textPrimary)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(themeManager.colors.brand.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - Image Card

    @ViewBuilder
    private func mediaImageCard(_ item: MediaItem, index: Int, width: CGFloat, height: CGFloat) -> some View {
        Button {
            selectedImageIndex = index
            showLightbox = true
        } label: {
            AsyncImage(url: URL(string: item.url)) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    Rectangle().fill(.gray.opacity(0.15))
                        .overlay {
                            Image(systemName: AppIcon.photo)
                                .foregroundStyle(.tertiary)
                        }
                }
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: AppIcon.arrowUpLeftAndArrowDownRight)
                    .font(ThemeFont.body(size: 10))
                    .foregroundStyle(ThemeColor.textPrimary)
                    .padding(5)
                    .background(.black.opacity(0.5), in: Circle())
                    .padding(6)
            }
        }
    }
}

// MARK: - Lightbox

struct MediaLightboxView: View {
    let images: [MediaItem]
    @Binding var selectedIndex: Int

    @Environment(\.dismiss) private var dismiss
    @State private var dragOffset: CGSize = .zero
    @GestureState private var isDragging = false

    var body: some View {
        ZStack {
            ThemeColor.bgBase.ignoresSafeArea()

            // Image viewer with zoom
            TabView(selection: $selectedIndex) {
                ForEach(Array(images.enumerated()), id: \.element.id) { index, item in
                    ZoomableImageView(url: item.url, isActive: index == selectedIndex)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            // Top bar
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: AppIcon.xmark)
                            .font(ThemeFont.body(size: 16, weight: .semibold))
                            .foregroundStyle(ThemeColor.textPrimary)
                            .padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                    }

                    Spacer()

                    // Counter
                    Text("\(selectedIndex + 1) / \(images.count)")
                        .font(ThemeFont.body(size: 12, weight: .bold).monospaced())
                        .foregroundStyle(ThemeColor.textPrimary.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())

                    Spacer()

                    // Spacer for balance
                    Color.clear.frame(width: 40, height: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                // Navigation arrows
                HStack {
                    if selectedIndex > 0 {
                        Button {
                            withAnimation { selectedIndex -= 1 }
                        } label: {
                            Image(systemName: AppIcon.chevronLeft)
                                .font(ThemeFont.display(size: 20, weight: .semibold))
                                .foregroundStyle(ThemeColor.textPrimary)
                                .padding(12)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                    }

                    Spacer()

                    if selectedIndex < images.count - 1 {
                        Button {
                            withAnimation { selectedIndex += 1 }
                        } label: {
                            Image(systemName: AppIcon.chevronRight)
                                .font(ThemeFont.display(size: 20, weight: .semibold))
                                .foregroundStyle(ThemeColor.textPrimary)
                                .padding(12)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }
}

// MARK: - Zoomable Image

/// A single image view with pinch-to-zoom and drag-to-pan support.
/// Double-tap resets scale to 1x.
private struct ZoomableImageView: View {
    let url: String
    /// Whether this page is the currently visible one. When it becomes inactive
    /// the zoom/pan is reset so returning to the image shows it at 1x.
    var isActive: Bool = true

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private func resetZoom() {
        scale = 1.0
        lastScale = 1.0
        offset = .zero
        lastOffset = .zero
    }

    var body: some View {
        GeometryReader { geometry in
            AsyncImage(url: URL(string: url)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(zoomGesture)
                        .gesture(panGesture(in: geometry.size))
                        .onTapGesture(count: 2) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if scale > 1.05 {
                                    // Reset
                                    scale = 1.0
                                    lastScale = 1.0
                                    offset = .zero
                                    lastOffset = .zero
                                } else {
                                    // Zoom in
                                    scale = 2.5
                                    lastScale = 2.5
                                }
                            }
                        }
                default:
                    ProgressView().tint(.white)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // A11Y-01: Provide meaningful label for VoiceOver
            .accessibilityLabel("Hình ảnh phóng to")
            .accessibilityHint("Chạm hai lần để phóng to hoặc thu nhỏ")
            .onChange(of: isActive) { _, active in
                if !active { resetZoom() }
            }
        }
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let newScale = lastScale * value
                scale = max(1.0, min(5.0, newScale))
            }
            .onEnded { value in
                let newScale = lastScale * value
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    scale = max(1.0, min(5.0, newScale))
                    if scale <= 1.05 {
                        scale = 1.0
                        offset = .zero
                        lastOffset = .zero
                    }
                }
                lastScale = scale
            }
    }

    private func panGesture(in size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1.0 else { return }
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
                // Clamp offset so image stays in bounds
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    clampOffset(in: size)
                }
            }
    }

    private func clampOffset(in size: CGSize) {
        let maxX = (scale - 1) * size.width / 2
        let maxY = (scale - 1) * size.height / 2
        offset.width = max(-maxX, min(maxX, offset.width))
        offset.height = max(-maxY, min(maxY, offset.height))
        lastOffset = offset
    }
}
