//
//  SubtitleOverlayView.swift
//  MovieStreamingApple
//
//  Renders the active subtitle cue on the player with full appearance customization.
//  Positioned at the bottom of the player with configurable vertical offset.
//  Moves up when HUD controls are visible to avoid overlap.
//
//  Styling is driven by SubtitleSettings: font, color, opacity, background,
//  edge style, and position — matching the web player's capability.
//

import SwiftUI

struct SubtitleOverlayView: View {
    let cue: SubtitleCue?
    let settings: SubtitleSettings
    let isHUDVisible: Bool

    /// Dynamic offset based on screen height ratio — adapts to any device.
    /// HUD bottom bar is ~16% of player height on most layouts.
    private func hudOffset(for playerHeight: CGFloat) -> CGFloat {
        max(50, playerHeight * 0.09)
    }

    var body: some View {
        GeometryReader { geometry in
            if let cue {
                let bottomInset = geometry.size.height * CGFloat(settings.verticalPosition / 100)

                VStack {
                    Spacer()

                    subtitleText(cue.text, maxWidth: geometry.size.width)
                        .padding(.bottom, bottomInset)
                        .offset(y: isHUDVisible ? -hudOffset(for: geometry.size.height) : 0)
                }
                .frame(maxWidth: .infinity)
                .animation(.easeInOut(duration: 0.25), value: isHUDVisible)
                .transition(.opacity)
            }
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .contain)
        .animation(.easeInOut(duration: 0.15), value: cue?.id)
    }

    // MARK: - Subtitle Text Rendering

    @ViewBuilder
    private func subtitleText(_ text: String, maxWidth: CGFloat) -> some View {
        Text(text)
            .font(settings.subtitleFont)
            .foregroundStyle(settings.textColor)
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(settings.bgColor, in: RoundedRectangle(cornerRadius: 6))
            .modifier(EdgeStyleModifier(edgeStyle: settings.edgeStyle))
            // Use parent geometry width instead of deprecated UIScreen.main
            .frame(maxWidth: maxWidth * 0.85)
            .accessibilityLabel(Text("Phụ đề: \(text)"))
    }
}
