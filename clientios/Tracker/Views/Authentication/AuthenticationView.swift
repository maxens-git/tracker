//
//  AuthenticationView.swift
//  Tracker
//
//  Feuille de connexion Authelia. Un WKWebView est nécessaire ici : contrairement
//  à Safari, son magasin de cookies est lisible et peut alimenter URLSession.
//

import SwiftUI
import WebKit

struct AuthenticationView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            AutheliaWebView()
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Connexion")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Annuler") { dismiss() }
                    }
                }
        }
        .interactiveDismissDisabled()
    }
}

private struct AutheliaWebView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        if let url = AppConfig.authenticationProbeURL {
            webView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData))
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        private var isCompleting = false

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !isCompleting,
                  webView.url?.host == AppConfig.productionHost else { return }

            isCompleting = true
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                Task { @MainActor in
                    for cookie in cookies where AppConfig.acceptsAuthenticationCookie(cookie) {
                        HTTPCookieStorage.shared.setCookie(cookie)
                    }
                    AuthenticationManager.shared.authenticationSucceeded()
                }
            }
        }
    }
}
