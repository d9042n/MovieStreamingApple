//
//  KenBurnsModifier.swift
//  MovieStreamingApple
//
//  A reusable Ken Burns effect that applies a subtle, continuous scaling
//  animation to views. Perfect for large hero images and posters.
//
//  Supports:
//  - Alternating zoom direction (in/out) for seamless carousel transitions
//  - Start delay for crossfade synchronisation (zoom begins after fade-in)
//  - One-shot mode that freezes at destination for smooth crossfade-out
//

import SwiftUI

private struct KenBurnsView<V: View>: View {
    let wrappedContent: V
    @State private var kenBurnsScale: CGFloat = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isActive: Bool
    let maxScale: CGFloat
    let duration: TimeInterval
    let reverse: Bool
    let repeats: Bool
    let startDelay: TimeInterval

    init(
        wrappedContent: V,
        isActive: Bool = true,
        maxScale: CGFloat = 1.05,
        duration: TimeInterval = 20.0,
        reverse: Bool = false,
        repeats: Bool = true,
        startDelay: TimeInterval = 0
    ) {
        self.wrappedContent = wrappedContent
        self.isActive = isActive
        self.maxScale = maxScale
        self.duration = duration
        self.reverse = reverse
        self.repeats = repeats
        self.startDelay = startDelay
    }

    var body: some View {
        wrappedContent
            .scaleEffect(kenBurnsScale)
            .onAppear {
                if isActive { startAnimation() }
            }
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    startAnimation()
                } else if repeats {
                    // Repeating → stop & reset to prevent infinite background loop
                    stopAnimation()
                }
                // One-shot (repeats=false) → freeze at current scale
                // so the outgoing slide keeps its zoom during crossfade-out
            }
            .onChange(of: reduceMotion) { _, isReduced in
                if isReduced {
                    stopAnimation()
                } else if isActive {
                    startAnimation()
                }
            }
    }

    private func startAnimation() {
        guard !reduceMotion else { return }

        let startScale: CGFloat = reverse ? maxScale : 1.0
        let endScale: CGFloat = reverse ? 1.0 : maxScale

        // Snap to starting scale instantly
        withAnimation(.linear(duration: 0)) {
            kenBurnsScale = startScale
        }

        // Build the animation with optional start delay
        let baseAnimation: Animation = .easeInOut(duration: duration)
        let finalAnimation: Animation
        if repeats {
            // Looping mode (detail pages, etc.) — delay not typically used
            finalAnimation = baseAnimation.repeatForever(autoreverses: true)
        } else if startDelay > 0 {
            // One-shot with delay — waits for crossfade to finish before zooming
            finalAnimation = baseAnimation.delay(startDelay)
        } else {
            finalAnimation = baseAnimation
        }

        withAnimation(finalAnimation) {
            kenBurnsScale = endScale
        }
    }

    private func stopAnimation() {
        let resetScale: CGFloat = reverse ? maxScale : 1.0
        withAnimation(.linear(duration: 0)) {
            kenBurnsScale = resetScale
        }
    }
}

extension View {
    /// Applies a continuous, cinematic zooming animation (Ken Burns).
    /// - Parameters:
    ///   - isActive: Controls whether the animation is running.
    ///   - maxScale: The peak scale factor (default: 1.05 for 5% zoom).
    ///   - duration: Duration of one zoom pass in seconds (default: 20s).
    ///   - reverse: If true, zooms out (maxScale → 1.0) instead of in.
    ///   - repeats: If true, loops forever with autoreversal.
    ///   - startDelay: Seconds to wait before zoom begins (for crossfade sync).
    func kenBurns(
        isActive: Bool = true,
        maxScale: CGFloat = 1.05,
        duration: TimeInterval = 20.0,
        reverse: Bool = false,
        repeats: Bool = true,
        startDelay: TimeInterval = 0
    ) -> some View {
        KenBurnsView(
            wrappedContent: self,
            isActive: isActive,
            maxScale: maxScale,
            duration: duration,
            reverse: reverse,
            repeats: repeats,
            startDelay: startDelay
        )
    }
}
