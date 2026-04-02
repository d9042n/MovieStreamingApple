//
//  ButtonStyles.swift
//  MovieStreamingApple
//
//  Centralized button styles reflecting the web version's .btn-primary and .btn-highlight.
//  All colors are dynamic — they respond to the user's selected theme.
//

import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.themeManager) private var themeManager

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ThemeFont.display(size: 14, weight: .bold))
            .textCase(.uppercase)
            .foregroundStyle(themeManager.colors.textInverse)
            .padding(.horizontal, 32)
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
                color: themeManager.colors.brand.opacity(configuration.isPressed ? 0.6 : 0.4),
                radius: configuration.isPressed ? 20 : 15,
                y: configuration.isPressed ? 6 : 4
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(DesignTokens.Animation.quick, value: configuration.isPressed)
    }
}

struct HighlightButtonStyle: ButtonStyle {
    @Environment(\.themeManager) private var themeManager

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ThemeFont.display(size: 14, weight: .bold))
            .textCase(.uppercase)
            .foregroundStyle(themeManager.colors.textOnAccent)
            .padding(.horizontal, 32)
            .padding(.vertical, 12)
            .background(themeManager.colors.highlight)
            .clipShape(Capsule())
            .shadow(
                color: themeManager.colors.highlight.opacity(configuration.isPressed ? 0.4 : 0.2),
                radius: configuration.isPressed ? 20 : 15,
                y: configuration.isPressed ? 6 : 4
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(DesignTokens.Animation.quick, value: configuration.isPressed)
    }
}

extension View {
    func primaryButton() -> some View {
        self.buttonStyle(PrimaryButtonStyle())
    }

    func highlightButton() -> some View {
        self.buttonStyle(HighlightButtonStyle())
    }
}
