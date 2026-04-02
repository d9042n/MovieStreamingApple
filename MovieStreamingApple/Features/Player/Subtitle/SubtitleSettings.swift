//
//  SubtitleSettings.swift
//  MovieStreamingApple
//
//  Subtitle appearance settings with UserDefaults persistence.
//  Mirrors the web's useSubtitleSettings hook: font, colors, opacity,
//  edge style, and position — all persisted across sessions.
//

import SwiftUI
import os

private let logger = Logger(subsystem: "com.d9042n.moviestreaming", category: "SubtitleSettings")

// MARK: - Edge Style

/// Text edge rendering style for subtitles.
enum SubtitleEdgeStyle: String, CaseIterable, Codable, Sendable, Identifiable {
    case none
    case dropShadow
    case raised
    case depressed
    case uniform

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "Không"
        case .dropShadow: return "Đổ bóng"
        case .raised: return "Nổi"
        case .depressed: return "Chìm"
        case .uniform: return "Viền đều"
        }
    }
}

// MARK: - Font Family

/// Available font families for subtitle rendering.
enum SubtitleFontFamily: String, CaseIterable, Codable, Sendable, Identifiable {
    case body    // Nunito
    case display // Dosis

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .body: return "Body (Nunito)"
        case .display: return "Display (Dosis)"
        }
    }

    /// Returns the appropriate ThemeFont for a given size and weight.
    func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch self {
        case .body: return ThemeFont.body(size: size, weight: weight)
        case .display: return ThemeFont.display(size: size, weight: weight)
        }
    }
}

// MARK: - Preset Color

/// Preset subtitle color options matching the web implementation.
struct SubtitleColor: Identifiable, Sendable, Equatable {
    let label: String
    let hex: String
    let color: Color

    var id: String { hex }

    /// All available preset colors (matches web COLORS array exactly).
    static let presets: [SubtitleColor] = [
        SubtitleColor(label: "Trắng", hex: "#FFFFFF", color: .white),
        SubtitleColor(label: "Đen", hex: "#000000", color: .black),
        SubtitleColor(label: "Vàng", hex: "#FFFF00", color: Color(hex: 0xFFFF00)),
        SubtitleColor(label: "Xanh lá", hex: "#00FF00", color: Color(hex: 0x00FF00)),
        SubtitleColor(label: "Xanh lam", hex: "#00FFFF", color: Color(hex: 0x00FFFF)),
        SubtitleColor(label: "Xanh dương", hex: "#0000FF", color: Color(hex: 0x0000FF)),
        SubtitleColor(label: "Hồng", hex: "#FF00FF", color: Color(hex: 0xFF00FF)),
        SubtitleColor(label: "Đỏ", hex: "#FF0000", color: Color(hex: 0xFF0000)),
    ]
}

// MARK: - SubtitleSettings Model

/// Observable subtitle appearance settings with automatic UserDefaults persistence.
@Observable
@MainActor
final class SubtitleSettings {

    // MARK: - Properties

    /// Font size as percentage (50–300, default 100 → 16pt at 100%)
    var fontSize: Double = 100 {
        didSet { save() }
    }

    /// Font family selection
    var fontFamily: SubtitleFontFamily = .body {
        didSet { save() }
    }

    /// Whether subtitle text is bold
    var textBold: Bool = false {
        didSet { save() }
    }

    /// Text color hex string
    var textColorHex: String = "#FFFFFF" {
        didSet { save() }
    }

    /// Text opacity (0–100, default 100)
    var textOpacity: Double = 100 {
        didSet { save() }
    }

    /// Background color hex string
    var bgColorHex: String = "#000000" {
        didSet { save() }
    }

    /// Background opacity (0–100, default 25)
    var bgOpacity: Double = 25 {
        didSet { save() }
    }

    /// Text edge rendering style
    var edgeStyle: SubtitleEdgeStyle = .none {
        didSet { save() }
    }

    /// Vertical position as percentage from bottom (0–20, default 6)
    var verticalPosition: Double = 6 {
        didSet { save() }
    }

    // MARK: - Persistence

    private static let storageKey = "moviestreaming_subtitle_settings"

    /// Debounce task — cancels previous save and waits 300ms before writing.
    private var saveTask: Task<Void, Never>?

    // MARK: - Computed Properties (for rendering)

    /// The actual font size in points, computed from percentage.
    var fontSizePoints: CGFloat {
        let basePt: CGFloat = 16
        return basePt * CGFloat(fontSize / 100)
    }

    /// The SwiftUI Font for subtitle rendering.
    var subtitleFont: Font {
        fontFamily.font(
            size: fontSizePoints,
            weight: textBold ? .bold : .regular
        )
    }

    /// Text color with opacity applied.
    var textColor: Color {
        Self.colorFromHex(textColorHex).opacity(textOpacity / 100)
    }

    /// Background color with opacity applied.
    var bgColor: Color {
        Self.colorFromHex(bgColorHex).opacity(bgOpacity / 100)
    }

    /// Shadow style for the text edge.
    var textShadow: some ShapeStyle {
        switch edgeStyle {
        case .none:
            return .clear
        case .dropShadow, .raised, .depressed, .uniform:
            return .black.opacity(0.8)
        }
    }

    /// Shadow radius for the current edge style.
    var shadowRadius: CGFloat {
        switch edgeStyle {
        case .none: return 0
        case .dropShadow: return 4
        case .raised: return 1
        case .depressed: return 1
        case .uniform: return 0
        }
    }

    /// Shadow offset for the current edge style.
    var shadowOffset: CGSize {
        switch edgeStyle {
        case .none: return .zero
        case .dropShadow: return CGSize(width: 0, height: 2)
        case .raised: return CGSize(width: -1, height: -1)
        case .depressed: return CGSize(width: 1, height: 1)
        case .uniform: return .zero
        }
    }

    /// Display label for the current text color from presets.
    var textColorLabel: String {
        SubtitleColor.presets.first { $0.hex == textColorHex }?.label ?? "Tùy chỉnh"
    }

    /// Display label for the current background color from presets.
    var bgColorLabel: String {
        SubtitleColor.presets.first { $0.hex == bgColorHex }?.label ?? "Tùy chỉnh"
    }

    // MARK: - Init

    init() {
        load()
    }

    // MARK: - Actions

    /// Reset all settings to their default values.
    func resetToDefaults() {
        fontSize = 100
        fontFamily = .body
        textBold = false
        textColorHex = "#FFFFFF"
        textOpacity = 100
        bgColorHex = "#000000"
        bgOpacity = 25
        edgeStyle = .none
        verticalPosition = 6
        save()
    }

    // MARK: - Private Persistence

    private func save() {
        // Debounce: cancel any pending save and wait 300ms.
        // This prevents writing UserDefaults ~60 times/s while dragging sliders.
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, let self else { return }
            self.performSave()
        }
    }

    private func performSave() {
        let data: [String: Any] = [
            "fontSize": fontSize,
            "fontFamily": fontFamily.rawValue,
            "textBold": textBold,
            "textColorHex": textColorHex,
            "textOpacity": textOpacity,
            "bgColorHex": bgColorHex,
            "bgOpacity": bgOpacity,
            "edgeStyle": edgeStyle.rawValue,
            "verticalPosition": verticalPosition,
        ]
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.dictionary(forKey: Self.storageKey) else { return }

        if let v = data["fontSize"] as? Double { fontSize = v }
        if let v = data["fontFamily"] as? String, let f = SubtitleFontFamily(rawValue: v) { fontFamily = f }
        if let v = data["textBold"] as? Bool { textBold = v }
        if let v = data["textColorHex"] as? String { textColorHex = v }
        if let v = data["textOpacity"] as? Double { textOpacity = v }
        if let v = data["bgColorHex"] as? String { bgColorHex = v }
        if let v = data["bgOpacity"] as? Double { bgOpacity = v }
        if let v = data["edgeStyle"] as? String, let e = SubtitleEdgeStyle(rawValue: v) { edgeStyle = e }
        if let v = data["verticalPosition"] as? Double { verticalPosition = v }
    }

    // MARK: - Hex → Color Conversion

    /// Convert a hex string like "#FF0000" to a SwiftUI Color.
    static func colorFromHex(_ hex: String) -> Color {
        var cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanHex.hasPrefix("#") { cleanHex.removeFirst() }

        guard cleanHex.count == 6,
              let rgb = UInt(cleanHex, radix: 16) else {
            return .white
        }

        return Color(hex: rgb)
    }
}
