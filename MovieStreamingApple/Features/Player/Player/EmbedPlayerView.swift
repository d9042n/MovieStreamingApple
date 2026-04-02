//
//  EmbedPlayerView.swift
//  MovieStreamingApple
//
//  WKWebView wrapper for embed-only servers (no HLS/M3U8).
//  Loads the server's link_embed URL inside a sandboxed WebView.
//

import SwiftUI
import WebKit

/// Displays an embedded video player inside a WKWebView.
struct EmbedPlayerView: UIViewRepresentable {
    let embedURL: String
    let onBack: (() -> Void)?

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Clear WebView when URL is empty (switched from embed to HLS server)
        guard !embedURL.isEmpty, let url = URL(string: embedURL) else {
            if context.coordinator.currentEmbedURL != nil {
                webView.loadHTMLString("", baseURL: nil)
                context.coordinator.currentEmbedURL = nil
                context.coordinator.allowedHost = nil
            }
            return
        }

        // Update allowed host for navigation policy
        context.coordinator.allowedHost = url.host

        // Only load if source URL changed (compare via coordinator tracking)
        if context.coordinator.currentEmbedURL != embedURL {
            context.coordinator.currentEmbedURL = embedURL
            webView.load(URLRequest(url: url))
        }
    }

    // ARCH-02: Explicitly clean up WKWebView on removal to prevent memory leaks
    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.stopLoading()
        webView.loadHTMLString("", baseURL: nil)
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var allowedHost: String?
        var currentEmbedURL: String?

        // MARK: - Navigation Policy (same-domain only)

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // P1-01: Check host even for .other (JS-initiated) navigations
            if let host = navigationAction.request.url?.host,
               host == allowedHost {
                decisionHandler(.allow)
                return
            }

            // Allow initial about:blank loads
            if navigationAction.request.url?.scheme == "about" {
                decisionHandler(.allow)
                return
            }

            // Block external navigations (ads, redirects to other sites)
            decisionHandler(.cancel)
        }

        // MARK: - Block Pop-ups

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            // Block pop-up windows from embed servers
            return nil
        }
    }
}

/// Wrapper view that shows embed player with back button overlay.
struct EmbedPlayerContainerView: View {
    let embedURL: String
    let title: String
    var onBack: (() -> Void)?

    var body: some View {
        ZStack {
            ThemeColor.bgBase.ignoresSafeArea()

            EmbedPlayerView(embedURL: embedURL, onBack: onBack)
                .ignoresSafeArea()

            // Minimal back button
            VStack {
                HStack {
                    Button {
                        onBack?()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: AppIcon.chevronLeft)
                                .font(ThemeFont.body(size: 16, weight: .semibold))
                            Text(title)
                                .font(ThemeFont.body(size: 12, weight: .bold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(ThemeColor.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                    }
                    .accessibilityLabel(Text("Quay lại"))

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()
            }
        }
        .statusBarHidden(true)
    }
}
