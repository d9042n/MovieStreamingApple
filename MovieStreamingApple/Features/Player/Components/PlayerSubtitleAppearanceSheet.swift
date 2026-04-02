//
//  PlayerSubtitleAppearanceSheet.swift
//  MovieStreamingApple
//
//  Comprehensive subtitle appearance customization screen.
//  Pushed via NavigationLink from PlayerSettingsSheet.
//  Mirrors the web's SettingsMenu sub-menus: font size, family, weight,
//  text color, text opacity, bg color, bg opacity, edge style, position.
//
//  Uses drill-down NavigationLinks for discrete selections and
//  inline sliders for continuous values (size, opacities, position)
//  with live preview text at the top.
//

import SwiftUI

struct PlayerSubtitleAppearanceSheet: View {
    @Bindable var settings: SubtitleSettings

    @Environment(\.themeManager) private var themeManager

    var body: some View {
        List {
            // Live preview
            Section {
                livePreview
            }

            // Position
            Section {
                sliderRow(
                    label: "Vị trí dọc",
                    icon: AppIcon.arrowUpAndDown,
                    value: $settings.verticalPosition,
                    range: 0...20,
                    step: 1,
                    unit: "%",
                    displayValue: "\(Int(settings.verticalPosition))%"
                )
            } header: {
                Text("Vị trí")
            }

            // Font
            Section {
                sliderRow(
                    label: "Cỡ chữ",
                    icon: AppIcon.textformatSize,
                    value: $settings.fontSize,
                    range: 50...300,
                    step: 5,
                    unit: "%",
                    displayValue: "\(Int(settings.fontSize))%"
                )

                NavigationLink {
                    fontFamilyPicker
                } label: {
                    settingsRow(
                        icon: AppIcon.textformat,
                        label: "Phông chữ",
                        hint: settings.fontFamily.displayName
                    )
                }

                NavigationLink {
                    fontWeightPicker
                } label: {
                    settingsRow(
                        icon: AppIcon.bold,
                        label: "Độ đậm",
                        hint: settings.textBold ? "Đậm" : "Thường"
                    )
                }
            } header: {
                Text("Phông chữ")
            }

            // Text Color & Opacity
            Section {
                NavigationLink {
                    textColorPicker
                } label: {
                    HStack(spacing: 12) {
                        colorSwatch(hex: settings.textColorHex)
                        Text("Màu chữ")
                            .font(ThemeFont.body(size: 15))
                        Spacer()
                        Text(settings.textColorLabel)
                            .font(ThemeFont.body(size: 13))
                            .foregroundStyle(ThemeColor.textMuted)
                    }
                }

                sliderRow(
                    label: "Độ mờ chữ",
                    icon: AppIcon.circleLefthalfFilled,
                    value: $settings.textOpacity,
                    range: 0...100,
                    step: 5,
                    unit: "%",
                    displayValue: "\(Int(settings.textOpacity))%"
                )
            } header: {
                Text("Màu chữ")
            }

            // Background Color & Opacity
            Section {
                NavigationLink {
                    bgColorPicker
                } label: {
                    HStack(spacing: 12) {
                        colorSwatch(hex: settings.bgColorHex)
                        Text("Màu nền")
                            .font(ThemeFont.body(size: 15))
                        Spacer()
                        Text(settings.bgColorLabel)
                            .font(ThemeFont.body(size: 13))
                            .foregroundStyle(ThemeColor.textMuted)
                    }
                }

                sliderRow(
                    label: "Độ mờ nền",
                    icon: AppIcon.circleLefthalfFilled,
                    value: $settings.bgOpacity,
                    range: 0...100,
                    step: 5,
                    unit: "%",
                    displayValue: "\(Int(settings.bgOpacity))%"
                )
            } header: {
                Text("Nền phụ đề")
            }

            // Edge Style
            Section {
                NavigationLink {
                    edgeStylePicker
                } label: {
                    settingsRow(
                        icon: AppIcon.shadow,
                        label: "Kiểu viền",
                        hint: settings.edgeStyle.displayName
                    )
                }
            } header: {
                Text("Viền chữ")
            }

            // Reset
            Section {
                Button(role: .destructive) {
                    withAnimation(DesignTokens.Animation.standard) {
                        settings.resetToDefaults()
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
        .navigationTitle("Tùy chỉnh phụ đề")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Live Preview

    private var livePreview: some View {
        ZStack {
            // Dark cinema background
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.large)
                .fill(ThemeColor.bgBase)
                .frame(height: 100)

            // Preview subtitle text
            Text("Xin chào, đây là phụ đề mẫu")
                .font(settings.subtitleFont)
                .foregroundStyle(settings.textColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(settings.bgColor, in: RoundedRectangle(cornerRadius: 6))
                .modifier(EdgeStyleModifier(edgeStyle: settings.edgeStyle))
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    // MARK: - Slider Row (for continuous values)

    @ViewBuilder
    private func sliderRow(
        label: String,
        icon: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        unit: String,
        displayValue: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(ThemeFont.body(size: 16, weight: .medium))
                    .foregroundStyle(ThemeColor.textMuted)
                    .frame(width: 24)

                Text(label)
                    .font(ThemeFont.body(size: 15))

                Spacer()

                Text(displayValue)
                    .font(ThemeFont.body(size: 13, weight: .bold))
                    .foregroundStyle(themeManager.colors.brand)
                    .monospacedDigit()
            }

            Slider(value: value, in: range, step: step)
                .tint(themeManager.colors.brand)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Settings Row (for NavigationLink labels)

    @ViewBuilder
    private func settingsRow(icon: String, label: String, hint: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(ThemeFont.body(size: 16, weight: .medium))
                .foregroundStyle(ThemeColor.textMuted)
                .frame(width: 24)

            Text(label)
                .font(ThemeFont.body(size: 15))

            Spacer()

            Text(hint)
                .font(ThemeFont.body(size: 13))
                .foregroundStyle(ThemeColor.textMuted)
        }
    }

    // MARK: - Color Swatch

    @ViewBuilder
    private func colorSwatch(hex: String) -> some View {
        Circle()
            .fill(SubtitleSettings.colorFromHex(hex))
            .frame(width: 22, height: 22)
            .overlay(
                Circle()
                    .stroke(.secondary.opacity(0.3), lineWidth: 1)
            )
    }

    // MARK: - Font Family Picker

    private var fontFamilyPicker: some View {
        List {
            ForEach(SubtitleFontFamily.allCases) { family in
                Button {
                    settings.fontFamily = family
                } label: {
                    HStack {
                        Text(family.displayName)
                            .font(family.font(size: 16))
                            .foregroundStyle(ThemeColor.textPrimary)

                        Spacer()

                        if settings.fontFamily == family {
                            Image(systemName: AppIcon.checkmark)
                                .font(ThemeFont.body(size: 16, weight: .semibold))
                                .foregroundStyle(themeManager.colors.brand)
                        }
                    }
                }
            }
        }
        .navigationTitle("Phông chữ")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Font Weight Picker

    private var fontWeightPicker: some View {
        List {
            Button {
                settings.textBold = false
            } label: {
                HStack {
                    Text("Thường")
                        .font(ThemeFont.body(size: 16))
                        .foregroundStyle(ThemeColor.textPrimary)
                    Spacer()
                    if !settings.textBold {
                        Image(systemName: AppIcon.checkmark)
                            .font(ThemeFont.body(size: 16, weight: .semibold))
                            .foregroundStyle(themeManager.colors.brand)
                    }
                }
            }

            Button {
                settings.textBold = true
            } label: {
                HStack {
                    Text("Đậm")
                        .font(ThemeFont.body(size: 16, weight: .bold))
                        .foregroundStyle(ThemeColor.textPrimary)
                    Spacer()
                    if settings.textBold {
                        Image(systemName: AppIcon.checkmark)
                            .font(ThemeFont.body(size: 16, weight: .semibold))
                            .foregroundStyle(themeManager.colors.brand)
                    }
                }
            }
        }
        .navigationTitle("Độ đậm")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Text Color Picker

    private var textColorPicker: some View {
        List {
            ForEach(SubtitleColor.presets) { preset in
                Button {
                    settings.textColorHex = preset.hex
                } label: {
                    HStack(spacing: 12) {
                        colorSwatch(hex: preset.hex)

                        Text(preset.label)
                            .font(ThemeFont.body(size: 16))
                            .foregroundStyle(ThemeColor.textPrimary)

                        Spacer()

                        if settings.textColorHex == preset.hex {
                            Image(systemName: AppIcon.checkmark)
                                .font(ThemeFont.body(size: 16, weight: .semibold))
                                .foregroundStyle(themeManager.colors.brand)
                        }
                    }
                }
            }
        }
        .navigationTitle("Màu chữ")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Background Color Picker

    private var bgColorPicker: some View {
        List {
            ForEach(SubtitleColor.presets) { preset in
                Button {
                    settings.bgColorHex = preset.hex
                } label: {
                    HStack(spacing: 12) {
                        colorSwatch(hex: preset.hex)

                        Text(preset.label)
                            .font(ThemeFont.body(size: 16))
                            .foregroundStyle(ThemeColor.textPrimary)

                        Spacer()

                        if settings.bgColorHex == preset.hex {
                            Image(systemName: AppIcon.checkmark)
                                .font(ThemeFont.body(size: 16, weight: .semibold))
                                .foregroundStyle(themeManager.colors.brand)
                        }
                    }
                }
            }
        }
        .navigationTitle("Màu nền")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Edge Style Picker

    private var edgeStylePicker: some View {
        List {
            ForEach(SubtitleEdgeStyle.allCases) { style in
                Button {
                    settings.edgeStyle = style
                } label: {
                    HStack {
                        // Preview of the edge style
                        Text("Abc")
                            .font(ThemeFont.body(size: 16, weight: .bold))
                            .foregroundStyle(ThemeColor.textPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.black, in: RoundedRectangle(cornerRadius: 4))
                            .modifier(EdgeStyleModifier(edgeStyle: style))

                        Text(style.displayName)
                            .font(ThemeFont.body(size: 16))
                            .foregroundStyle(ThemeColor.textPrimary)
                            .padding(.leading, 8)

                        Spacer()

                        if settings.edgeStyle == style {
                            Image(systemName: AppIcon.checkmark)
                                .font(ThemeFont.body(size: 16, weight: .semibold))
                                .foregroundStyle(themeManager.colors.brand)
                        }
                    }
                }
            }
        }
        .navigationTitle("Kiểu viền")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Edge Style Modifier (shared with SubtitleOverlayView)

/// Applies the appropriate shadow/stroke based on the subtitle edge style.
/// Declared internal so both SubtitleOverlayView and SubtitleAppearanceSheet can use it.
struct EdgeStyleModifier: ViewModifier {
    let edgeStyle: SubtitleEdgeStyle

    // NOTE: The project has a domain model `struct Content` (Core/Models/Content.swift)
    // that shadows `ViewModifier.Content`. We use `_content` parameter name and wrap
    // each branch in `Group` to avoid the ambiguity.
    func body(content _content: Self.Content) -> some View {
        Group {
            switch edgeStyle {
            case .none:
                _content

            case .dropShadow:
                _content
                    .shadow(color: ThemeColor.bgBase.opacity(0.8), radius: 4, x: 0, y: 2)
                    .shadow(color: ThemeColor.bgBase.opacity(0.4), radius: 8, x: 0, y: 4)

            case .raised:
                _content
                    .shadow(color: ThemeColor.bgBase.opacity(0.8), radius: 0, x: -1, y: -1)
                    .shadow(color: ThemeColor.textPrimary.opacity(0.3), radius: 0, x: 1, y: 1)

            case .depressed:
                _content
                    .shadow(color: ThemeColor.bgBase.opacity(0.8), radius: 0, x: 1, y: 1)
                    .shadow(color: ThemeColor.textPrimary.opacity(0.3), radius: 0, x: -1, y: -1)

            case .uniform:
                _content
                    .shadow(color: ThemeColor.bgBase, radius: 0, x: 1, y: 1)
                    .shadow(color: ThemeColor.bgBase, radius: 0, x: -1, y: -1)
                    .shadow(color: ThemeColor.bgBase, radius: 0, x: 1, y: -1)
                    .shadow(color: ThemeColor.bgBase, radius: 0, x: -1, y: 1)
            }
        }
    }
}
