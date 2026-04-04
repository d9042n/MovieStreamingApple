//
//  ProfileView.swift
//  MovieStreamingApple
//
//  User profile page — settings, theme selection, account management.
//  Grouped settings iOS-standard pattern with branded icons and dividers.
//

import SwiftUI

struct ProfileView: View {
    @Environment(\.themeManager) private var themeManager
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(WatchHistoryManager.self) private var historyManager
    @State private var isThemePickerPresented = false
    @State private var showClearHistoryConfirm = false
    @AppStorage("useMathTransformFullscreen") private var useMathTransformFullscreen = false

    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.xxl) {
                // Profile Header
                profileHeader

                // Settings Sections
                VStack(spacing: DesignTokens.Spacing.lg) {
                    // Appearance
                    settingsSection(title: "Giao diện") {
                        themeRow
                    }

                    // Account (placeholder — not yet implemented)
                    settingsSection(title: "Tài khoản") {
                        settingsRow(
                            icon: AppIcon.personFill,
                            title: "Thông tin cá nhân",
                            subtitle: "Đăng nhập để đồng bộ",
                            isDisabled: true
                        )
                        sectionDivider
                        settingsRow(
                            icon: AppIcon.bellFill,
                            title: "Thông báo",
                            subtitle: "Bật",
                            isDisabled: true
                        )
                    }

                    // Library
                    settingsSection(title: "Thư viện") {
                        settingsRow(
                            icon: AppIcon.clockArrowCirclepath,
                            title: "Lịch sử xem",
                            subtitle: historyManager.isEmpty
                                ? nil
                                : "\(historyManager.entries.count) phim",
                            isDisabled: true
                        )
                        sectionDivider
                        settingsRow(
                            icon: AppIcon.heartFill,
                            title: "Yêu thích",
                            subtitle: nil,
                            isDisabled: true
                        )
                        sectionDivider
                        settingsRow(
                            icon: AppIcon.arrowDownCircleFill,
                            title: "Tải xuống",
                            subtitle: nil,
                            isDisabled: true
                        )
                    }

                    // Video Player
                    settingsSection(title: "Trình Phát (Player)") {
                        settingsToggleRow(
                            icon: AppIcon.ipadLandscape,
                            title: "Xoay ngang khi phóng to",
                            subtitle: useMathTransformFullscreen
                                ? "Tự động xoay ngang video kể cả khi thiết bị khoá hướng dọc."
                                : "Tuân thủ cài đặt khoá xoay của hệ thống.",
                            isOn: $useMathTransformFullscreen
                        )
                    }

                    // Data & Storage
                    settingsSection(title: "Dữ liệu") {
                        settingsButtonRow(
                            icon: AppIcon.trash,
                            title: "Xoá lịch sử xem",
                            subtitle: historyManager.isEmpty ? "Trống" : "\(historyManager.entries.count) mục",
                            isDestructive: true,
                            isDisabled: historyManager.isEmpty
                        ) {
                            showClearHistoryConfirm = true
                        }
                    }

                    // App Info
                    settingsSection(title: "Ứng dụng") {
                        settingsRow(
                            icon: AppIcon.infoCircleFill,
                            title: "Phiên bản",
                            subtitle: Bundle.main.fullVersionString
                        )
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.horizontalPadding(hSizeClass))
            }
            .padding(.vertical, DesignTokens.Spacing.xl)
            .adaptiveContainer()
        }
        .scrollIndicators(.hidden)
        .background(ThemeColor.bgBase.ignoresSafeArea())
        .navigationTitle("Hồ sơ")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $isThemePickerPresented) {
            ProfileThemePicker()
        }
        .confirmationDialog(
            "Xoá tất cả lịch sử xem?",
            isPresented: $showClearHistoryConfirm,
            titleVisibility: .visible
        ) {
            Button("Xoá tất cả", role: .destructive) {
                withAnimation(DesignTokens.Animation.standard) {
                    historyManager.clearAll()
                }
            }
            Button("Huỷ", role: .cancel) {}
        } message: {
            Text("Hành động này không thể hoàn tác. Tất cả tiến trình xem sẽ bị mất.")
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [themeManager.colors.brand, themeManager.colors.highlight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: AppIcon.personFill)
                    .font(ThemeFont.display(size: 32))
                    .foregroundStyle(.white)
            }

            Text("Khách")
                .font(ThemeFont.display(size: 20, weight: .bold))
                .foregroundStyle(themeManager.colors.textPrimary)

            Button {
                // TODO: Implement login
            } label: {
                Text("Đăng nhập")
                    .font(ThemeFont.body(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, DesignTokens.Spacing.xxl)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .background(themeManager.colors.brand, in: Capsule())
            }
        }
        .padding(.vertical, DesignTokens.Spacing.lg)
    }

    // MARK: - Theme Row (special)

    private var themeRow: some View {
        Button {
            isThemePickerPresented = true
        } label: {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: AppIcon.paintpaletteFill)
                    .font(ThemeFont.body(size: 16))
                    .foregroundStyle(themeManager.colors.brand)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Giao diện")
                        .font(ThemeFont.body(size: 15, weight: .semibold))
                        .foregroundStyle(themeManager.colors.textPrimary)

                    Text(themeManager.selectedTheme.displayName)
                        .font(ThemeFont.body(size: 12))
                        .foregroundStyle(themeManager.colors.textMuted)
                }

                Spacer()

                // Current theme color swatch
                HStack(spacing: 3) {
                    Circle().fill(themeManager.colors.brand).frame(width: 10, height: 10)
                    Circle().fill(themeManager.colors.highlight).frame(width: 10, height: 10)
                }

                Image(systemName: AppIcon.chevronRight)
                    .font(ThemeFont.body(size: 12, weight: .semibold))
                    .foregroundStyle(themeManager.colors.textMuted)
            }
            .padding(.vertical, DesignTokens.Spacing.md)
            .padding(.horizontal, DesignTokens.Spacing.lg)
        }
        .buttonStyle(.plain)
        // A11Y: Announce current theme
        .accessibilityLabel("Giao diện: \(themeManager.selectedTheme.displayName)")
        .accessibilityHint("Nhấn để thay đổi giao diện")
    }

    // MARK: - Settings Section

    private func settingsSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(ThemeFont.display(size: 12, weight: .bold))
                .foregroundStyle(themeManager.colors.textMuted)
                .tracking(1)
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.bottom, DesignTokens.Spacing.sm)

            VStack(spacing: 0) {
                content()
            }
            .background(themeManager.colors.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.large))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.large)
                    .strokeBorder(themeManager.colors.border.opacity(0.2), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Section Divider

    private var sectionDivider: some View {
        Divider()
            .background(themeManager.colors.border.opacity(0.15))
            .padding(.leading, DesignTokens.Spacing.lg + 28 + DesignTokens.Spacing.md) // icon width + spacing
    }

    // MARK: - Settings Row (generic)

    private func settingsRow(icon: String, title: String, subtitle: String?, isDisabled: Bool = false) -> some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: icon)
                .font(ThemeFont.body(size: 16))
                .foregroundStyle(isDisabled ? themeManager.colors.textMuted : themeManager.colors.brand.opacity(0.8))
                .frame(width: 28)

            Text(title)
                .font(ThemeFont.body(size: 15, weight: .semibold))
                .foregroundStyle(themeManager.colors.textPrimary)

            Spacer()

            if let subtitle {
                Text(subtitle)
                    .font(ThemeFont.body(size: 13))
                    .foregroundStyle(themeManager.colors.textMuted)
            }

            // UX-03: Only show chevron for interactive rows
            if !isDisabled {
                Image(systemName: AppIcon.chevronRight)
                    .font(ThemeFont.body(size: 12, weight: .semibold))
                    .foregroundStyle(themeManager.colors.textMuted)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.md)
        .padding(.horizontal, DesignTokens.Spacing.lg)
        // UX-03: Dim disabled rows to signal non-interactivity
        .opacity(isDisabled ? 0.5 : 1.0)
        // A11Y-03: Mark disabled rows appropriately
        .accessibilityAddTraits(isDisabled ? [] : .isButton)
        .accessibilityHint(isDisabled ? "Sắp ra mắt" : "")
    }

    // MARK: - Settings Button Row (interactive, e.g. clear history)

    private func settingsButtonRow(
        icon: String,
        title: String,
        subtitle: String?,
        isDestructive: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: icon)
                    .font(ThemeFont.body(size: 16))
                    .foregroundStyle(isDestructive ? themeManager.colors.statusError : themeManager.colors.brand)
                    .frame(width: 28)

                Text(title)
                    .font(ThemeFont.body(size: 15, weight: .semibold))
                    .foregroundStyle(isDestructive ? themeManager.colors.statusError : themeManager.colors.textPrimary)

                Spacer()

                if let subtitle {
                    Text(subtitle)
                        .font(ThemeFont.body(size: 13))
                        .foregroundStyle(themeManager.colors.textMuted)
                }
            }
            .padding(.vertical, DesignTokens.Spacing.md)
            .padding(.horizontal, DesignTokens.Spacing.lg)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.4 : 1.0)
    }

    // MARK: - Settings Toggle Row

    private func settingsToggleRow(icon: String, title: String, subtitle: String?, isOn: Binding<Bool>) -> some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: icon)
                .font(ThemeFont.body(size: 16))
                .foregroundStyle(themeManager.colors.brand.opacity(0.8))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ThemeFont.body(size: 15, weight: .semibold))
                    .foregroundStyle(themeManager.colors.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(ThemeFont.body(size: 12))
                        .foregroundStyle(themeManager.colors.textMuted)
                }
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(themeManager.colors.brand)
        }
        .padding(.vertical, DesignTokens.Spacing.md)
        .padding(.horizontal, DesignTokens.Spacing.lg)
        // A11Y: Describe toggle function
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(isOn.wrappedValue ? "Bật" : "Tắt")
    }
}

// MARK: - Preview

#Preview("Profile") {
    NavigationStack {
        ProfileView()
    }
    .environment(WatchHistoryManager())
    .environment(\.themeManager, ThemeManager())
    .preferredColorScheme(.dark)
}
