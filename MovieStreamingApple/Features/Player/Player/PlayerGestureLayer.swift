//
//  PlayerGestureLayer.swift
//  MovieStreamingApple
//
//  Transparent gesture detection overlay for the video player.
//  Handles: single tap (HUD), double/triple tap (seek), long press (2x speed),
//  vertical swipes (brightness/volume), horizontal swipes (scrubbing).
//
//  Gesture zones (YouTube/Netflix style):
//  ┌──────────┬──────────┬──────────┐
//  │  LEFT    │  CENTER  │  RIGHT   │
//  │ bright.  │  HUD     │  volume  │
//  │ seek ◀◀  │  play    │  seek ▶▶ │
//  └──────────┴──────────┴──────────┘
//
//  Architecture: Single DragGesture(minimumDistance: 0) handles BOTH
//  long press and drag to avoid SwiftUI gesture conflicts.
//  onTapGesture handles tap detection separately.
//
//  Visual indicators are rendered by PlayerIndicatorLayer (separate Z layer).
//

import SwiftUI

/// Transparent overlay that captures all player gestures.
/// Does NOT render any visual indicators — those are in PlayerIndicatorLayer.
struct PlayerGestureLayer: View {
    @Bindable var viewModel: VideoPlayerViewModel

    // MARK: - Local State

    @State private var tapCount = 0
    @State private var tapSide: TapSide = .center
    @State private var tapTimer: Task<Void, Never>?

    // Unified gesture state
    @State private var gestureMode: GestureMode = .idle
    @State private var longPressTimer: Task<Void, Never>?

    // Drag tracking
    @State private var dragStartLocation: CGPoint = .zero
    @State private var scrubStartTime: TimeInterval = 0

    // Drag start snapshots for absolute calculation
    @State private var dragStartBrightness: CGFloat = 0
    @State private var dragStartVolume: Float = 0

    private enum TapSide { case left, center, right }
    private enum DragAxis { case horizontal, vertical }
    private enum GestureMode: Equatable {
        case idle
        case waitingForLongPress     // Finger down, timer counting
        case longPressing            // Timer fired, 2x speed active
        case dragging(DragAxis)      // Significant movement detected
    }

    // MARK: - Configuration

    private let seekPerTap: Int = 10           // Each tap: ±10s (YouTube standard)
    private let dragThreshold: CGFloat = 12    // Min distance to start drag
    private let axisLockBias: CGFloat = 1.4    // Bias to distinguish horizontal vs vertical
    private let longPressDuration: Double = 0.2  // 200ms to trigger long press

    var body: some View {
        GeometryReader { geo in
            Color.clear
                .contentShape(Rectangle())

                // MARK: Tap Gesture

                .onTapGesture(count: 2) { location in
                    guard !viewModel.isLocked else { return }
                    let side = tapSideFor(location: location, in: geo.size)
                    handleDoubleTap(side: side)
                }
                .onTapGesture { location in
                    guard !viewModel.isLocked else { return }
                    // Single tap: ALWAYS toggle HUD instantly, no delay
                    viewModel.toggleHUD()
                }

                // MARK: Unified Drag Gesture (handles long press + drag)
                // Use .simultaneousGesture so DragGesture fires .onChanged
                // on first touch-down WITHOUT waiting for tap disambiguation.
                // .gesture() (default priority) is delayed by onTapGesture
                // recognizers, adding ~50-100ms hidden latency to long press.

                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard !viewModel.isLocked else { return }
                            handleGestureChanged(value: value, size: geo.size)
                        }
                        .onEnded { _ in
                            handleGestureEnded()
                        }
                )
        }
    }

    // MARK: - Tap Handling

    private func tapSideFor(location: CGPoint, in size: CGSize) -> TapSide {
        let third = size.width / 3
        if location.x < third { return .left }
        if location.x > third * 2 { return .right }
        return .center
    }

    /// Double tap on sides → seek ±10s. Double tap center → ignored (single tap toggles HUD).
    private func handleDoubleTap(side: TapSide) {
        guard side != .center else { return }

        if side == .right {
            viewModel.seekForward(by: seekPerTap)
        } else {
            viewModel.seekBackward(by: seekPerTap)
        }
    }

    // MARK: - Unified Gesture Handling (Long Press + Drag)

    private func handleGestureChanged(value: DragGesture.Value, size: CGSize) {
        switch gestureMode {
        case .idle:
            // First frame — start tracking
            dragStartLocation = value.startLocation
            scrubStartTime = viewModel.currentTime
            dragStartBrightness = viewModel.currentBrightness
            dragStartVolume = viewModel.currentVolume
            gestureMode = .waitingForLongPress

            // Start long press timer (200ms — snappy like YouTube)
            longPressTimer?.cancel()
            longPressTimer = Task {
                try? await Task.sleep(for: .seconds(longPressDuration))
                guard !Task.isCancelled else { return }
                // Timer fired — enter long press mode
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
            // Screen-proportional scrub (matches progress bar: full width = full duration)
            let fraction = Double(value.translation.width) / Double(size.width)
            let delta = fraction * viewModel.duration
            viewModel.scrubDelta = delta
            viewModel.isScrubbing = true
            let targetTime = max(0, min(viewModel.duration, scrubStartTime + delta))
            viewModel.seek(to: targetTime)

        case .vertical:
            // Left half → brightness, Right half → volume
            let isLeftSide = dragStartLocation.x < size.width / 2

            // Absolute calculation from start position
            let normalizedDelta = -value.translation.height / (size.height * 0.8)

            if isLeftSide {
                let newBrightness = dragStartBrightness + normalizedDelta
                viewModel.setBrightness(newBrightness)
            } else {
                let newVolume = dragStartVolume + Float(normalizedDelta)
                viewModel.setVolume(newVolume)
            }
        }
    }

    private func handleGestureEnded() {
        // Cancel any pending long press timer
        longPressTimer?.cancel()
        longPressTimer = nil

        // End long press if active
        if gestureMode == .longPressing {
            viewModel.endLongPress()
        }

        // Reset scrub state on viewModel
        viewModel.isScrubbing = false
        viewModel.scrubDelta = 0
        gestureMode = .idle
    }
}
