//
//  AVPlayerLayerView.swift
//  MovieStreamingApple
//
//  UIViewRepresentable wrapper for AVPlayerLayer.
//  Renders the actual video frames with hardware acceleration.
//

import AVFoundation
import SwiftUI

/// SwiftUI wrapper around AVPlayerLayer for native video rendering.
struct AVPlayerLayerView: UIViewRepresentable {
    let player: AVPlayer?

    func makeUIView(context: Context) -> PlayerUIView {
        PlayerUIView()
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        // Only reassign if player reference actually changed
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
    }

    /// Simple UIView subclass with AVPlayerLayer as its backing layer.
    final class PlayerUIView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }

        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

        override init(frame: CGRect) {
            super.init(frame: frame)
            playerLayer.videoGravity = .resizeAspect
            backgroundColor = .black
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError() }
    }
}
