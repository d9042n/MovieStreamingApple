//
//  DesignTokens.swift
//  MovieStreamingApple
//
//  Centralized design tokens matching Apple Human Interface Guidelines.
//

import SwiftUI

enum DesignTokens {
    // MARK: - Spacing

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }

    // MARK: - Corner Radius

    enum CornerRadius {
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
        static let extraLarge: CGFloat = 16
        static let card: CGFloat = 16
        static let poster: CGFloat = 12
    }

    // MARK: - Animation

    enum Animation {
        /// Near-instant UI response — subtle state flips (spring, no bounce)
        static let micro: SwiftUI.Animation = .smooth(duration: 0.1)
        /// Quick transitions — tab switches, toggles, HUD show/hide (spring, slight snap)
        static let quick: SwiftUI.Animation = .snappy(duration: 0.2)
        /// Quick fade-out — player seek/volume/brightness indicators (timing curve, non-interactive)
        static let quickOut: SwiftUI.Animation = .easeOut(duration: 0.15)
        /// Standard transitions — panel slides, list expansions, modal toggles (spring, smooth)
        static let standard: SwiftUI.Animation = .smooth(duration: 0.3)
        /// Slow transitions — hero slide changes, large reveals (spring, smooth)
        static let slow: SwiftUI.Animation = .smooth(duration: 0.5)
        /// Bouncy spring — emphasis interactions, scale up/down, playful taps
        static let spring: SwiftUI.Animation = .bouncy(duration: 0.4)
    }

    // MARK: - Poster Size

    enum PosterSize {
        static let gridWidth: CGFloat = 160
        static let gridHeight: CGFloat = 240
        static let railWidth: CGFloat = 140
        static let railHeight: CGFloat = 210
        static let heroHeight: CGFloat = 450
    }
}
