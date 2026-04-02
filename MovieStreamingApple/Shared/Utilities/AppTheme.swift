//
//  AppTheme.swift
//  MovieStreamingApple
//
//  Centralized multi-theme system matching the web's ThemeContext.
//  Supports: Midnight Cinema, Sapphire Night, Emerald Night, Crimson Velvet, Amethyst Night.
//

import SwiftUI

// MARK: - Theme ID

/// Matches the web's `Theme` type from ThemeContext.tsx
enum ThemeID: String, CaseIterable, Identifiable, Codable, Sendable {
    case midnight
    case sapphire
    case emerald
    case velvet
    case amethyst

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .midnight: return "Midnight Cinema"
        case .sapphire: return "Sapphire Night"
        case .emerald: return "Emerald Night"
        case .velvet: return "Crimson Velvet"
        case .amethyst: return "Amethyst Night"
        }
    }

    var icon: String {
        switch self {
        case .midnight: return "moon.stars.fill"
        case .sapphire: return "drop.fill"
        case .emerald: return "leaf.fill"
        case .velvet: return "flame.fill"
        case .amethyst: return "sparkles"
        }
    }

    /// Preview color swatch for the theme picker
    var previewColors: [Color] {
        switch self {
        case .midnight:
            return [Color(hex: 0x020617), Color(hex: 0xe11d48), Color(hex: 0xf59e0b)]
        case .sapphire:
            return [Color(hex: 0x020617), Color(hex: 0x3b82f6), Color(hex: 0x818cf8)]
        case .emerald:
            return [Color(hex: 0x022c22), Color(hex: 0x10b981), Color(hex: 0xfbbf24)]
        case .velvet:
            return [Color(hex: 0x1c1917), Color(hex: 0xfb7185), Color(hex: 0xfcd34d)]
        case .amethyst:
            return [Color(hex: 0x13111C), Color(hex: 0x7C3AED), Color(hex: 0xC026D3)]
        }
    }
}

// MARK: - Theme Colors (Dynamic)

/// All color tokens for the current theme. Mirrors the web's CSS custom properties.
struct ThemeColors: Sendable {
    // Backgrounds
    let bgBase: Color
    let bgCard: Color
    let bgCardAlt: Color
    let bgInput: Color
    let bgGlass: Color

    // Accents
    let brand: Color
    let brandHover: Color
    let highlight: Color
    let link: Color
    let cyan: Color

    // Text
    let textPrimary: Color
    let textBody: Color
    let textMuted: Color
    let textOnAccent: Color
    let textInverse: Color

    // Status
    let statusSuccess: Color
    let statusWarning: Color
    let statusError: Color
    let statusInfo: Color

    // Borders
    let border: Color
    let borderHover: Color

    // Overlays
    let overlaySubtle: Color
    let overlayCard: Color
}

// MARK: - Theme Definitions (matching web CSS exactly)

extension ThemeColors {
    /// Default: Midnight Cinema (base dark theme from web)
    static let midnight = ThemeColors(
        bgBase: Color(hex: 0x020617),
        bgCard: Color(hex: 0x0f172a),
        bgCardAlt: Color(hex: 0x1e293b),
        bgInput: Color(hex: 0x334155),
        bgGlass: Color(hex: 0x020617).opacity(0.75),
        brand: Color(hex: 0xe11d48),
        brandHover: Color(hex: 0xbe123c),
        highlight: Color(hex: 0xf59e0b),
        link: Color(hex: 0x38bdf8),
        cyan: Color(hex: 0x06b6d4),
        textPrimary: Color(hex: 0xf1f5f9),
        textBody: Color(hex: 0xabb7c4),
        textMuted: Color(hex: 0xa0aec0),
        textOnAccent: Color(hex: 0x020617),
        textInverse: .white,
        statusSuccess: Color(hex: 0x22c55e),
        statusWarning: Color(hex: 0xf59e0b),
        statusError: Color(hex: 0xef4444),
        statusInfo: Color(hex: 0x3b82f6),
        border: Color(hex: 0x405266),
        borderHover: Color(hex: 0xf59e0b),
        overlaySubtle: Color.white.opacity(0.05),
        overlayCard: Color.black.opacity(0.3)
    )

    /// Sapphire Night — HBO Max / Disney+ premium blue vibe
    static let sapphire = ThemeColors(
        bgBase: Color(hex: 0x020617),
        bgCard: Color(hex: 0x0c1a3a),
        bgCardAlt: Color(hex: 0x1e3a5f),
        bgInput: Color(hex: 0x1e40af),
        bgGlass: Color(hex: 0x040d21).opacity(0.75),
        brand: Color(hex: 0x3b82f6),
        brandHover: Color(hex: 0x2563eb),
        highlight: Color(hex: 0x818cf8),
        link: Color(hex: 0x67e8f9),
        cyan: Color(hex: 0x22d3ee),
        textPrimary: Color(hex: 0xe0e7ff),
        textBody: Color(hex: 0x94a3b8),
        textMuted: Color(hex: 0x64748b),
        textOnAccent: .white,
        textInverse: .white,
        statusSuccess: Color(hex: 0x34d399),
        statusWarning: Color(hex: 0xfbbf24),
        statusError: Color(hex: 0xf87171),
        statusInfo: Color(hex: 0x60a5fa),
        border: Color(hex: 0x1e3a5f),
        borderHover: Color(hex: 0x818cf8),
        overlaySubtle: Color(hex: 0x6366f1).opacity(0.05),
        overlayCard: Color.black.opacity(0.3)
    )

    /// Emerald Night — Nature-inspired, organic calm
    static let emerald = ThemeColors(
        bgBase: Color(hex: 0x022c22),
        bgCard: Color(hex: 0x064e3b),
        bgCardAlt: Color(hex: 0x065f46),
        bgInput: Color(hex: 0x047857),
        bgGlass: Color(hex: 0x022c22).opacity(0.75),
        brand: Color(hex: 0x10b981),
        brandHover: Color(hex: 0x059669),
        highlight: Color(hex: 0xfbbf24),
        link: Color(hex: 0x6ee7b7),
        cyan: Color(hex: 0x2dd4bf),
        textPrimary: Color(hex: 0xecfdf5),
        textBody: Color(hex: 0xa7f3d0),
        textMuted: Color(hex: 0x6ee7b7),
        textOnAccent: Color(hex: 0x022c22),
        textInverse: .white,
        statusSuccess: Color(hex: 0x4ade80),
        statusWarning: Color(hex: 0xfbbf24),
        statusError: Color(hex: 0xf87171),
        statusInfo: Color(hex: 0x38bdf8),
        border: Color(hex: 0x065f46),
        borderHover: Color(hex: 0xfbbf24),
        overlaySubtle: Color(hex: 0x10b981).opacity(0.05),
        overlayCard: Color.black.opacity(0.3)
    )

    /// Crimson Velvet — Luxury cinema, warm jewel tones
    static let velvet = ThemeColors(
        bgBase: Color(hex: 0x1c1917),
        bgCard: Color(hex: 0x292524),
        bgCardAlt: Color(hex: 0x44403c),
        bgInput: Color(hex: 0x57534e),
        bgGlass: Color(hex: 0x1c1917).opacity(0.75),
        brand: Color(hex: 0xfb7185),
        brandHover: Color(hex: 0xf43f5e),
        highlight: Color(hex: 0xfcd34d),
        link: Color(hex: 0xc4b5fd),
        cyan: Color(hex: 0xf472b6),
        textPrimary: Color(hex: 0xfafaf9),
        textBody: Color(hex: 0xd6d3d1),
        textMuted: Color(hex: 0xa8a29e),
        textOnAccent: Color(hex: 0x1c1917),
        textInverse: .white,
        statusSuccess: Color(hex: 0x4ade80),
        statusWarning: Color(hex: 0xfcd34d),
        statusError: Color(hex: 0xfb7185),
        statusInfo: Color(hex: 0xa78bfa),
        border: Color(hex: 0x57534e),
        borderHover: Color(hex: 0xfcd34d),
        overlaySubtle: Color(hex: 0xfb7185).opacity(0.05),
        overlayCard: Color.black.opacity(0.3)
    )

    /// Amethyst Night — Purple pastel dark, Twitch / Discord inspired
    static let amethyst = ThemeColors(
        bgBase: Color(hex: 0x13111C),
        bgCard: Color(hex: 0x1E1A2E),
        bgCardAlt: Color(hex: 0x2A2540),
        bgInput: Color(hex: 0x352F4A),
        bgGlass: Color(hex: 0x13111C).opacity(0.75),
        brand: Color(hex: 0x7C3AED),
        brandHover: Color(hex: 0x6D28D9),
        highlight: Color(hex: 0xC026D3),
        link: Color(hex: 0xC4B5FD),
        cyan: Color(hex: 0xE879F9),
        textPrimary: Color(hex: 0xF5F3FF),
        textBody: Color(hex: 0xDDD6FE),
        textMuted: Color(hex: 0xA09ABC),
        textOnAccent: .white,
        textInverse: .white,
        statusSuccess: Color(hex: 0x4ade80),
        statusWarning: Color(hex: 0xfbbf24),
        statusError: Color(hex: 0xf87171),
        statusInfo: Color(hex: 0x818cf8),
        border: Color(hex: 0x3B3555),
        borderHover: Color(hex: 0xC084FC),
        overlaySubtle: Color(hex: 0x7C3AED).opacity(0.06),
        overlayCard: Color.black.opacity(0.3)
    )

    /// Lookup by ThemeID
    static func colors(for theme: ThemeID) -> ThemeColors {
        switch theme {
        case .midnight: return .midnight
        case .sapphire: return .sapphire
        case .emerald: return .emerald
        case .velvet: return .velvet
        case .amethyst: return .amethyst
        }
    }
}

// MARK: - Theme Manager

/// Observable theme manager — persists selection with @AppStorage.
/// Inject into environment at app root.
@Observable
@MainActor
final class ThemeManager {
    /// The currently selected theme ID
    var selectedTheme: ThemeID {
        didSet {
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: Self.storageKey)
        }
    }

    /// Computed colors for the current theme
    var colors: ThemeColors {
        ThemeColors.colors(for: selectedTheme)
    }

    private static let storageKey = "moviestreaming-theme"

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.storageKey) ?? ""
        self.selectedTheme = ThemeID(rawValue: stored) ?? .midnight
    }

    func setTheme(_ theme: ThemeID) {
        withAnimation(DesignTokens.Animation.standard) {
            selectedTheme = theme
        }
    }
}

// MARK: - Environment Key

private struct ThemeManagerKey: EnvironmentKey {
    static let defaultValue = ThemeManager()
}

extension EnvironmentValues {
    var themeManager: ThemeManager {
        get { self[ThemeManagerKey.self] }
        set { self[ThemeManagerKey.self] = newValue }
    }
}

// MARK: - Legacy Compatibility

/// Static accessor for places not yet using dynamic themes.
/// Prefer `@Environment(\.themeManager)` in views.
enum ThemeColor {
    // MARK: - Backgrounds
    static let bgBase = Color(hex: 0x020617)
    static let bgCard = Color(hex: 0x0f172a)
    static let bgCardAlt = Color(hex: 0x1e293b)
    static let bgGlass = Color(hex: 0x020617).opacity(0.75)

    // MARK: - Accents
    static let brand = Color(hex: 0xe11d48)
    static let brandHover = Color(hex: 0xbe123c)
    static let highlight = Color(hex: 0xf59e0b)
    static let link = Color(hex: 0x38bdf8)

    // MARK: - Text
    static let textPrimary = Color(hex: 0xf1f5f9)
    static let textBody = Color(hex: 0xabb7c4)
    static let textMuted = Color(hex: 0xa0aec0)
    static let textInverse = Color.white

    // MARK: - Status & Utility
    static let border = Color(hex: 0x405266)
    static let borderHover = Color(hex: 0xf59e0b)
    static let overlaySubtle = Color.white.opacity(0.05)
    static let overlayCard = Color.black.opacity(0.3)
}

// MARK: - Typography

/// Defines the core typography matching the web design (Dosis for display, Nunito for body).
/// Uses specific PostScript names from the variable font files for reliable weight mapping.
enum ThemeFont {
    // MARK: - Display Font (Dosis) — used for headings, titles, badges

    /// Maps SwiftUI `Font.Weight` to Dosis PostScript name.
    private static func dosisName(for weight: Font.Weight) -> String {
        switch weight {
        case .ultraLight, .thin: return "Dosis-ExtraLight"
        case .light: return "Dosis-Light"
        case .regular: return "Dosis-Regular"
        case .medium: return "Dosis-Medium"
        case .semibold: return "Dosis-SemiBold"
        case .bold: return "Dosis-Bold"
        case .heavy, .black: return "Dosis-ExtraBold"
        default: return "Dosis-Regular"
        }
    }

    // MARK: - Body Font (Nunito) — used for body text, captions

    /// Maps SwiftUI `Font.Weight` to Nunito PostScript name.
    private static func nunitoName(for weight: Font.Weight) -> String {
        switch weight {
        case .ultraLight, .thin: return "Nunito-ExtraLight"
        case .light: return "Nunito-Light"
        case .regular: return "Nunito-Regular"
        case .medium: return "Nunito-Medium"
        case .semibold: return "Nunito-SemiBold"
        case .bold: return "Nunito-Bold"
        case .heavy: return "Nunito-ExtraBold"
        case .black: return "Nunito-Black"
        default: return "Nunito-Regular"
        }
    }

    /// Display font (Dosis) — headings, titles, badges.
    /// Scales with Dynamic Type relative to an appropriate text style.
    static func display(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        let style = textStyle(for: size)
        return .custom(dosisName(for: weight), size: size, relativeTo: style)
    }

    /// Body font (Nunito) — body text, captions, descriptions.
    /// Scales with Dynamic Type relative to an appropriate text style.
    static func body(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let style = textStyle(for: size)
        return .custom(nunitoName(for: weight), size: size, relativeTo: style)
    }

    /// Maps a point size to the closest text style for Dynamic Type scaling.
    private static func textStyle(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case ...9: return .caption2
        case 10...11: return .caption
        case 12...13: return .footnote
        case 14...15: return .subheadline
        case 16...17: return .body
        case 18...20: return .title3
        case 21...24: return .title2
        case 25...30: return .title
        default: return .largeTitle
        }
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 08) & 0xff) / 255,
            blue: Double((hex >> 00) & 0xff) / 255,
            opacity: alpha
        )
    }
}
