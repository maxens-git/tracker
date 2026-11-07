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
    /// Vrai jusqu'au premier affichage du portail : le WKWebView reste blanc
    /// pendant le démarrage de son processus et le chargement de la page.
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            AutheliaWebView(isLoading: $isLoading)
                .ignoresSafeArea(edges: .bottom)
                .overlay {
                    if isLoading { ProgressView() }
                }
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
    @Binding var isLoading: Bool

    func makeCoordinator() -> Coordinator { Coordinator(isLoading: $isLoading) }

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
        @Binding private var isLoading: Bool

        init(isLoading: Binding<Bool>) {
            _isLoading = isLoading
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading = false
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            isLoading = false
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
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
