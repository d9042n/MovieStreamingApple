//
//  PlayerGestureLayer.swift
//  MovieStreamingApple
//
//  Transparent gesture detection overlay for the video player.
//  Handles: single tap (HUD), double/triple tap on sides (seek), long press (2x speed),
//  vertical swipes (brightness/volume), horizontal swipes (scrubbing).
//
//  Gesture zones (YouTube/Netflix style):
//  ┌──────────┬──────────┬──────────┐
//  │  LEFT    │  CENTER  │  RIGHT   │
//  │ bright.  │  HUD     │  volume  │
//  │ seek ◀◀  │  play    │  seek ▶▶ │
//  └──────────┴──────────┴──────────┘
//
//  Architecture: ONE DragGesture(minimumDistance: 0) handles EVERYTHING —
//  tap, double-tap, long press and drag — so there are no competing
//  recognizers and therefore no SwiftUI disambiguation delay or collisions.
//
//  • A touch that lifts before `longPressDuration` and without moving past
//    `dragThreshold` is a TAP.
//  • Center taps toggle the HUD INSTANTLY (no double-tap action there).
//  • Side taps wait `doubleTapWindow` to disambiguate single (HUD) from
//    double+ (seek, accumulating on rapid taps).
//  • Holding past `longPressDuration` without moving → 2x speed.
//  • Moving past `dragThreshold` → scrub (horizontal) / brightness·volume (vertical).
//
//  Visual indicators are rendered by PlayerIndicatorLayer (separate Z layer).
//

import SwiftUI

/// Transparent overlay that captures all player gestures.
/// Does NOT render any visual indicators — those are in PlayerIndicatorLayer.
struct PlayerGestureLayer: View {
    @Bindable var viewModel: VideoPlayerViewModel

    // MARK: - Unified gesture state

    @State private var gestureMode: GestureMode = .idle
    @State private var longPressTimer: Task<Void, Never>?

    // Drag tracking
    @State private var dragStartLocation: CGPoint = .zero
    @State private var scrubStartTime: TimeInterval = 0

    // Drag start snapshots for absolute calculation
    @State private var dragStartBrightness: CGFloat = 0
    @State private var dragStartVolume: Float = 0

    // Tap disambiguation (single vs double, side-aware)
    @State private var tapCount = 0
    @State private var lastTapSide: TapSide = .center
    @State private var tapResetTask: Task<Void, Never>?

    private enum TapSide { case left, center, right }
    private enum DragAxis { case horizontal, vertical }
    private enum GestureMode: Equatable {
        case idle
        case waitingForLongPress     // Finger down, timer counting
        case longPressing            // Timer fired, 2x speed active
        case dragging(DragAxis)      // Significant movement detected
    }

    // MARK: - Configuration

    private let seekPerTap: Int = 10            // Each double-tap: ±10s (YouTube standard)
    private let dragThreshold: CGFloat = 12     // Min distance to start drag
    private let axisLockBias: CGFloat = 1.4     // Bias to distinguish horizontal vs vertical
    private let longPressDuration: Double = 0.4 // Hold threshold for 2x (above a relaxed tap)
    private let doubleTapWindow: Double = 0.30  // Window to detect a second side tap (~platform double-tap interval)

    var body: some View {
        GeometryReader { geo in
            Color.clear
                .contentShape(Rectangle())
                // Single unified recognizer — fires onChanged on the very first
                // touch-down frame (minimumDistance: 0) with no tap-recognizer delay.
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard !viewModel.isLocked else { return }
                            handleGestureChanged(value: value, size: geo.size)
                        }
                        .onEnded { _ in
                            handleGestureEnded(size: geo.size)
                        }
                )
        }
    }

    // MARK: - Unified Gesture Handling

    private func handleGestureChanged(value: DragGesture.Value, size: CGSize) {
        switch gestureMode {
        case .idle:
            // First frame — start tracking
            dragStartLocation = value.startLocation
            scrubStartTime = viewModel.currentTime
            dragStartBrightness = viewModel.currentBrightness
            dragStartVolume = viewModel.currentVolume
            gestureMode = .waitingForLongPress

            // Start long press timer (held without moving → 2x speed)
            longPressTimer?.cancel()
            longPressTimer = Task {
                try? await Task.sleep(for: .seconds(longPressDuration))
                guard !Task.isCancelled else { return }
                // A deliberate hold supersedes any pending single-tap.
                tapResetTask?.cancel()
                tapResetTask = nil
                gestureMode = .longPressing
                viewModel.startLongPress()
            }

        case .waitingForLongPress:
            // Check if finger moved enough to switch to drag
            let dx = abs(value.translation.width)
            let dy = abs(value.translation.height)
            let distance = sqrt(dx * dx + dy * dy)

            if distance > dragThreshold {
                // Cancel long press timer — this is a drag
                longPressTimer?.cancel()
                longPressTimer = nil

                // Determine drag axis with bias to avoid misclassification on diagonal swipes.
                // Require 1.4x dominance to lock axis; otherwise wait for clearer intent.
                let axis: DragAxis?
                if dx > dy * axisLockBias {
                    axis = .horizontal
                } else if dy > dx * axisLockBias {
                    axis = .vertical
                } else {
                    // Ambiguous angle — wait for more movement
                    axis = nil
                }

                if let axis {
                    // A drag supersedes any pending single-tap from a previous touch.
                    tapResetTask?.cancel()
                    tapResetTask = nil
                    gestureMode = .dragging(axis)
                    viewModel.hapticImpact(.light)
                    // Process first drag frame
                    processDrag(value: value, axis: axis, size: size)
                }
                // else: stay in waitingForLongPress until angle resolves
            }

        case .longPressing:
            // Already in long press mode, nothing to do while held
            break

        case .dragging(let axis):
            // Continue processing drag
            processDrag(value: value, axis: axis, size: size)
        }
    }

    private func processDrag(value: DragGesture.Value, axis: DragAxis, size: CGSize) {
        switch axis {
        case .horizontal:
            // Screen-proportional scrub (matches progress bar: full width = full duration).
            // Preview only — defer the actual precise seek to gesture end (#3).
            guard size.width > 1 else { return }
            let fraction = Double(value.translation.width) / Double(size.width)
            let delta = fraction * viewModel.duration
            viewModel.scrubDelta = delta
            viewModel.previewScrub(to: scrubStartTime + delta)

        case .vertical:
            // Left half → brightness, Right half → volume
            let isLeftSide = dragStartLocation.x < size.width / 2

            // Absolute calculation from start position.
            // Guard against a degenerate (zero/near-zero) height during transient layout passes.
            let denom = size.height * 0.8
            guard denom > 1 else { return }
            let normalizedDelta = -value.translation.height / denom

            if isLeftSide {
                let newBrightness = dragStartBrightness + normalizedDelta
                viewModel.setBrightness(newBrightness)
            } else {
                let newVolume = dragStartVolume + Float(normalizedDelta)
                viewModel.setVolume(newVolume)
            }
        }
    }

    private func handleGestureEnded(size: CGSize) {
        // Cancel any pending long press timer
        longPressTimer?.cancel()
        longPressTimer = nil

        switch gestureMode {
        case .longPressing:
            viewModel.endLongPress()

        case .dragging(let axis):
            if axis == .horizontal {
                // Commit a horizontal scrub with a single precise seek (#3).
                viewModel.commitScrub()
            } else {
                viewModel.isScrubbing = false
                viewModel.scrubDelta = 0
            }

        case .waitingForLongPress, .idle:
            // Finger lifted before moving or long-pressing → it's a tap.
            guard !viewModel.isLocked else { break }
            let side = tapSideFor(location: dragStartLocation, in: size)
            registerTap(side: side)
        }

        gestureMode = .idle
    }

    // MARK: - Tap Handling

    private func tapSideFor(location: CGPoint, in size: CGSize) -> TapSide {
        guard size.width > 0 else { return .center }
        let third = size.width / 3
        if location.x < third { return .left }
        if location.x > third * 2 { return .right }
        return .center
    }

    /// Register a completed tap. Center toggles the HUD instantly; side taps
    /// disambiguate single (HUD) vs double+ (seek) within `doubleTapWindow`.
    private func registerTap(side: TapSide) {
        if side == .center {
            // Center has no double-tap action — toggle immediately for a snappy feel.
            tapResetTask?.cancel()
            tapResetTask = nil
            tapCount = 0
            lastTapSide = .center
            viewModel.toggleHUD()
            return
        }

        // A tap on the other side restarts the sequence.
        if side != lastTapSide { tapCount = 0 }
        lastTapSide = side
        tapCount += 1

        if tapCount >= 2 {
            // Double (or further) tap on a side → seek; accumulates on rapid taps.
            if side == .right {
                viewModel.seekForward(by: seekPerTap)
            } else {
                viewModel.seekBackward(by: seekPerTap)
            }
            // Re-arm the window so a 3rd/4th tap keeps accumulating, then reset.
            tapResetTask?.cancel()
            tapResetTask = Task {
                try? await Task.sleep(for: .seconds(doubleTapWindow))
                guard !Task.isCancelled else { return }
                tapCount = 0
                lastTapSide = .center
            }
            return
        }

        // First tap on a side → wait to see if a second arrives; else toggle HUD.
        tapResetTask?.cancel()
        tapResetTask = Task {
            try? await Task.sleep(for: .seconds(doubleTapWindow))
            guard !Task.isCancelled else { return }
            viewModel.toggleHUD()
            tapCount = 0
            lastTapSide = .center
        }
    }
}
