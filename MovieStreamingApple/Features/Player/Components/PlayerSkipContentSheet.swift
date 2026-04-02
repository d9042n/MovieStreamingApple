//
//  PlayerSkipContentSheet.swift
//  MovieStreamingApple
//
//  Sub-page for configuring intro & outro skip durations.
//  Pushed via NavigationLink from PlayerSettingsSheet.
//  Follows PlayerSubtitleAppearanceSheet multi-section pattern.
//
//  Each section (intro / outro) has:
//  - Custom input TextField (with backend suggestion placeholder — TODO)
//  - Quick-select preset duration list with checkmark
//

import SwiftUI

struct PlayerSkipContentSheet: View {
    @Bindable var settings: SkipContentSettings

    @Environment(\.themeManager) private var themeManager

    @State private var customIntroText = ""
    @State private var customOutroText = ""
    @FocusState private var introFieldFocused: Bool
    @FocusState private var outroFieldFocused: Bool

    var body: some View {
        List {
            // === Intro Section ===
            skipSection(
                header: String(localized: "Bỏ qua intro"),
                footer: String(localized: "Tự động bỏ qua phần đầu mỗi tập phim"),
                duration: settings.introSkipDuration,
                suggestedDuration: settings.suggestedIntroDuration,
                customText: $customIntroText,
                isFocused: $introFieldFocused,
                onDurationChange: { settings.introSkipDuration = $0 }
            )

            // === Outro Section ===
            skipSection(
                header: String(localized: "Bỏ qua outro"),
                footer: String(localized: "Tự động bỏ qua phần cuối mỗi tập phim"),
                duration: settings.outroSkipDuration,
                suggestedDuration: settings.suggestedOutroDuration,
                customText: $customOutroText,
                isFocused: $outroFieldFocused,
                onDurationChange: { settings.outroSkipDuration = $0 }
            )

            // === Reset Section ===
            Section {
                Button(role: .destructive) {
                    withAnimation(DesignTokens.Animation.standard) {
                        settings.resetToDefaults()
                        syncCustomTexts()
                    }
                } label: {
                    HStack {
                        Image(systemName: AppIcon.arrowCounterclockwise)
                            .font(ThemeFont.body(size: 16, weight: .medium))
                        Text("Đặt lại mặc định")
                            .font(ThemeFont.body(size: 15, weight: .medium))
                    }
                }
            }
        }
        .navigationTitle("Bỏ qua intro & outro")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Xong") {
                    introFieldFocused = false
                    outroFieldFocused = false
                }
                .font(ThemeFont.body(size: 15, weight: .semibold))
            }
        }
        .onAppear { syncCustomTexts() }
    }

    // MARK: - Reusable Section Builder

    @ViewBuilder
    private func skipSection(
        header: String,
        footer: String,
        duration: TimeInterval,
        suggestedDuration: TimeInterval?,
        customText: Binding<String>,
        isFocused: FocusState<Bool>.Binding,
        onDurationChange: @escaping (TimeInterval) -> Void
    ) -> some View {
        Section {
            // Custom input row
            HStack {
                TextField(
                    suggestedDuration.map { "\(Int($0))" } ?? String(localized: "Nhập giây"),
                    text: customText
                )
                .keyboardType(.numberPad)
                .font(ThemeFont.body(size: 15))
                .focused(isFocused)
                .onChange(of: customText.wrappedValue) { _, newValue in
                    applyCustomValue(newValue, onDurationChange: onDurationChange)
                }

                Text("giây")
                    .font(ThemeFont.body(size: 14))
                    .foregroundStyle(ThemeColor.textMuted)
            }

            // TODO: Backend suggested value hint
            // When API provides per-episode intro/outro timestamps,
            // populate suggestedDuration and this hint will appear.
            if let suggested = suggestedDuration {
                HStack(spacing: 6) {
                    Image(systemName: AppIcon.sparkles)
                        .font(ThemeFont.body(size: 11))
                    Text("Gợi ý: \(SkipContentSettings.formatDuration(suggested))")
                        .font(ThemeFont.body(size: 12))
                }
                .foregroundStyle(themeManager.colors.brand.opacity(0.8))
            }

            // Preset options
            ForEach(SkipContentSettings.presets) { option in
                Button {
                    onDurationChange(option.duration)
                    customText.wrappedValue = option.duration > 0
                        ? "\(Int(option.duration))" : ""
                } label: {
                    HStack {
                        Text(option.label)
                            .font(ThemeFont.body(size: 16))
                            .foregroundStyle(ThemeColor.textPrimary)

                        Spacer()

                        if duration == option.duration {
                            Image(systemName: AppIcon.checkmark)
                                .font(ThemeFont.body(size: 16, weight: .semibold))
                                .foregroundStyle(themeManager.colors.brand)
                        }
                    }
                }
            }
        } header: {
            Text(header)
        } footer: {
            Text(footer)
        }
    }

    // MARK: - Helpers

    /// Parse custom text input and apply if valid.
    private func applyCustomValue(_ text: String, onDurationChange: (TimeInterval) -> Void) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            onDurationChange(0)
            return
        }
        guard let seconds = Double(trimmed) else { return }
        let clamped = max(0, min(seconds, SkipContentSettings.maxCustomDuration))
        onDurationChange(clamped)
    }

    /// Sync custom text fields with current settings values.
    private func syncCustomTexts() {
        customIntroText = settings.introSkipDuration > 0
            ? "\(Int(settings.introSkipDuration))" : ""
        customOutroText = settings.outroSkipDuration > 0
            ? "\(Int(settings.outroSkipDuration))" : ""
    }
}
