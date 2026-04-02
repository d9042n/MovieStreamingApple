//
//  ShimmerModifier.swift
//  MovieStreamingApple
//
//  Loading shimmer animation effect for skeleton views.
//  Uses View wrapper instead of ViewModifier to avoid
//  naming conflict with the app's Content model type.
//

import SwiftUI

extension View {
    func shimmer() -> some View {
        ShimmerView(content: self)
    }
}

private struct ShimmerView<V: View>: View {
    let content: V
    @State private var phase: CGFloat = 0

    var body: some View {
        content
            .overlay {
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.04),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.5)
                    .offset(x: geo.size.width * (phase - 0.5))
                    .allowsHitTesting(false)
                }
                .clipped()
            }
            .onAppear {
                withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                    phase = 1.5
                }
            }
    }
}
