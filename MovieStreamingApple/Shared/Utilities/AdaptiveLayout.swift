//
//  AdaptiveLayout.swift
//  MovieStreamingApple
//
//  Centralized adaptive layout utilities for iPhone/iPad support.
//  Uses Size Class branching (Apple recommended) instead of device idiom checks.
//
//  Key concept:
//    .compact  = iPhone (all orientations) + iPad in narrow multitask
//    .regular  = iPad portrait/landscape (full or 2/3 width)
//
//  Within .regular, use GeometryReader width for fine-tuning:
//    < 900pt  = iPad Portrait / narrow → 2-column sidebar not ideal
//    ≥ 900pt  = iPad Landscape / wide → show sidebar
//

import SwiftUI

// MARK: - Adaptive Spacing

extension DesignTokens.Spacing {
    /// Horizontal padding for main content areas.
    /// Compact: 16pt (iPhone), Regular: 32–40pt (iPad)
    static func horizontalPadding(_ sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? lg : 40
    }

    /// Section spacing between major content blocks.
    static func sectionSpacing(_ sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? xxxl : 48
    }
}

// MARK: - Adaptive Grid Columns

extension DesignTokens {
    /// Grid column definitions that adapt to available width.
    enum AdaptiveGrid {
        /// For content poster cards (2:3 ratio) — adapts from 2 cols (iPhone) to 4-6 (iPad)
        static func posterColumns(_ sizeClass: UserInterfaceSizeClass?) -> [GridItem] {
            if sizeClass == .compact {
                return [
                    GridItem(.flexible(), spacing: Spacing.md, alignment: .top),
                    GridItem(.flexible(), spacing: Spacing.md, alignment: .top),
                ]
            } else {
                // iPad: adaptive columns — fits as many ~160pt-wide cards as possible
                return [GridItem(.adaptive(minimum: 150, maximum: 200), spacing: Spacing.lg, alignment: .top)]
            }
        }

        /// For browse page — denser grid on iPad
        static func browseColumns(_ sizeClass: UserInterfaceSizeClass?) -> [GridItem] {
            if sizeClass == .compact {
                return [
                    GridItem(.flexible(), spacing: Spacing.md, alignment: .top),
                    GridItem(.flexible(), spacing: Spacing.md, alignment: .top),
                ]
            } else {
                return [GridItem(.adaptive(minimum: 160, maximum: 220), spacing: Spacing.lg, alignment: .top)]
            }
        }

        /// For people grid
        static func peopleColumns(_ sizeClass: UserInterfaceSizeClass?) -> [GridItem] {
            if sizeClass == .compact {
                return [GridItem(.adaptive(minimum: 100), spacing: Spacing.md, alignment: .top)]
            } else {
                return [GridItem(.adaptive(minimum: 130, maximum: 180), spacing: Spacing.lg, alignment: .top)]
            }
        }
    }
}

// MARK: - Max Content Width

extension DesignTokens {
    /// Maximum content width to prevent layouts from stretching too wide on iPad
    /// (mirrors the web's `max-w-7xl` = 1280px)
    static let maxContentWidth: CGFloat = 1200

    /// Whether to show sidebar on iPad (requires sufficient width)
    static let sidebarBreakpoint: CGFloat = 900

    /// Sidebar width when shown
    static let sidebarWidth: CGFloat = 320
}

// MARK: - Adaptive Container

/// View wrapper that constrains content to maxContentWidth on iPad.
/// Avoids ViewModifier to prevent `Content` type-name collision with model.
struct AdaptiveContainer<V: View>: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass
    let content: V

    init(@ViewBuilder content: () -> V) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: hSizeClass == .regular ? DesignTokens.maxContentWidth : .infinity)
    }
}

extension View {
    /// Centers content with a max width on iPad, pass-through on iPhone.
    func adaptiveContainer() -> some View {
        AdaptiveContainer { self }
    }
}

// MARK: - Hero Image Priority

extension Content {
    /// Returns the preferred image URL based on size class.
    /// - Compact: Prioritize poster (portrait, 2:3)
    /// - Regular: Prioritize backdrop (landscape, 16:9)
    func heroImageURL(for sizeClass: UserInterfaceSizeClass?) -> URL? {
        let urlString: String?
        if sizeClass == .regular {
            // iPad: prefer wide backdrop
            urlString = (backdropUrl?.isEmpty == false ? backdropUrl : posterUrl)
        } else {
            // iPhone: prefer poster
            urlString = (posterUrl?.isEmpty == false ? posterUrl : backdropUrl)
        }
        guard let str = urlString, !str.isEmpty else { return nil }
        return URL(string: str)
    }
}
