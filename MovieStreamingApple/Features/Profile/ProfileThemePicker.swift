//
//  ProfileThemePicker.swift
//  MovieStreamingApple
//
//  Theme selection UI — lets users choose between 5 premium cinema themes.
//  Presented as a sheet from Profile or Settings.
//

import SwiftUI

struct ProfileThemePicker: View {
    @Environment(\.themeManager) private var themeManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.xl) {
                    // Header
                    headerSection

                    // Theme Cards
                    VStack(spacing: DesignTokens.Spacing.md) {
                        ForEach(ThemeID.allCases) { theme in
                            ThemeOptionCard(
                                theme: theme,
                                isSelected: themeManager.selectedTheme == theme
                            ) {
                                themeManager.setTheme(theme)
                            }
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                }
                .padding(.vertical, DesignTokens.Spacing.xl)
            }
            .background(themeManager.colors.bgBase.ignoresSafeArea())
            .navigationTitle("Giao diện")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Xong") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(themeManager.colors.brand)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: AppIcon.paintpaletteFill)
                .font(ThemeFont.display(size: 40))
                .foregroundStyle(
                    LinearGradient(
                        colors: [themeManager.colors.brand, themeManager.colors.highlight],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.bottom, DesignTokens.Spacing.xs)

            Text("Chọn giao diện")
                .font(ThemeFont.display(size: 22, weight: .bold))
                .foregroundStyle(themeManager.colors.textPrimary)

            Text("Cá nhân hóa trải nghiệm xem phim của bạn")
                .font(ThemeFont.body(size: 14))
                .foregroundStyle(themeManager.colors.textMuted)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, DesignTokens.Spacing.xxl)
    }
}

// MARK: - Theme Option Card

private struct ThemeOptionCard: View {
    let theme: ThemeID
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.themeManager) private var themeManager

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.lg) {
                // Color Preview
                colorPreview

                // Info
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Image(systemName: theme.icon)
                            .font(ThemeFont.body(size: 14))
                            .foregroundStyle(ThemeColors.colors(for: theme).brand)

                        Text(theme.displayName)
                            .font(ThemeFont.display(size: 16, weight: .bold))
                            .foregroundStyle(themeManager.colors.textPrimary)
                    }

                    Text(themeDescription)
                        .font(ThemeFont.body(size: 12))
                        .foregroundStyle(themeManager.colors.textMuted)
                        .lineLimit(1)
                }

                Spacer()

                // Selection indicator
                ZStack {
                    Circle()
                        .strokeBorder(
                            isSelected ? ThemeColors.colors(for: theme).brand : themeManager.colors.border,
                            lineWidth: 2
                        )
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(ThemeColors.colors(for: theme).brand)
                            .frame(width: 14, height: 14)
                    }
                }
                .animation(DesignTokens.Animation.quick, value: isSelected)
            }
            .padding(DesignTokens.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.large)
                    .fill(isSelected ? themeManager.colors.bgCardAlt : themeManager.colors.bgCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.large)
                    .strokeBorder(
                        isSelected
                            ? ThemeColors.colors(for: theme).brand.opacity(0.5)
                            : themeManager.colors.border.opacity(0.3),
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }

    // MARK: - Color Preview Swatch

    private var colorPreview: some View {
        let themeColors = ThemeColors.colors(for: theme)
        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(themeColors.bgBase)
                .frame(width: 48, height: 48)

            HStack(spacing: 2) {
                Circle()
                    .fill(themeColors.brand)
                    .frame(width: 12, height: 12)
                Circle()
                    .fill(themeColors.highlight)
                    .frame(width: 12, height: 12)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(themeManager.colors.border.opacity(0.3), lineWidth: 0.5)
        )
    }

    // MARK: - Theme Descriptions

    private var themeDescription: String {
        switch theme {
        case .midnight: return "Đêm khuya cổ điển, sắc đỏ mạnh mẽ"
        case .sapphire: return "Xanh sapphire cao cấp, thanh lịch"
        case .emerald: return "Xanh ngọc lục bảo, thiên nhiên yên bình"
        case .velvet: return "Nhung đỏ sang trọng, ấm áp"
        case .amethyst: return "Tím thạch anh, hiện đại và phá cách"
        }
    }
}

// MARK: - Preview

#Preview("Theme Picker") {
    ProfileThemePicker()
        .environment(\.themeManager, ThemeManager())
}
