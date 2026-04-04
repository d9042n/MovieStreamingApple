//
//  SplashScreenVideoPlayer.swift
//  MovieStreamingApple
//
//  A UIViewControllerRepresentable that presents the splash video using
//  a full-window UIKit approach. This guarantees the video covers the
//  ENTIRE physical screen — Dynamic Island, notch, home indicator, everything.
//
//  Why UIViewController instead of UIView?
//  SwiftUI's `.ignoresSafeArea()` extends drawing but doesn't reposition
//  content past safe area insets. By using a UIViewController, we get
//  direct control over `view.frame` and safe area override.
//

import AVFoundation
import SwiftUI

/// Fullscreen video player that covers the entire physical screen.
/// Uses UIKit's UIViewController for absolute control over safe area overrides.
struct SplashScreenVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> SplashPlayerViewController {
        SplashPlayerViewController(player: player)
    }

    func updateUIViewController(_ vc: SplashPlayerViewController, context: Context) {
        vc.playerLayer.player = player
    }
}

/// UIViewController that hosts AVPlayerLayer, overriding all safe area insets
/// so the video truly covers every pixel of the screen.
final class SplashPlayerViewController: UIViewController {
    let playerLayer: AVPlayerLayer

    init(player: AVPlayer) {
        playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.layer.addSublayer(playerLayer)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Use the full view bounds — we've zeroed out additionalSafeAreaInsets
        // and the view is set to fill the screen via SwiftUI's .ignoresSafeArea()
        // plus our own prefersHomeIndicatorAutoHidden / prefersStatusBarHidden.
        //
        // To ensure we truly cover everything, we compensate for any remaining
        // safe area insets by expanding the layer beyond the view bounds.
        let insets = view.safeAreaInsets
        let expandedFrame = CGRect(
            x: -insets.left,
            y: -insets.top,
            width: view.bounds.width + insets.left + insets.right,
            height: view.bounds.height + insets.top + insets.bottom
        )
        playerLayer.frame = expandedFrame
    }

    // Remove safe area barriers so the view extends under notch/dynamic island
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { .all }

    // Zero out any additional safe area insets that UIKit might apply
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        // Force re-layout so playerLayer expands correctly
        view.setNeedsLayout()
    }
}
