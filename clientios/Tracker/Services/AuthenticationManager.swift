//
//  AuthenticationManager.swift
//  Tracker
//
//  Détecte une session Authelia absente/expirée et pilote la connexion web.
//

import Foundation

@Observable
@MainActor
final class AuthenticationManager {
    static let shared = AuthenticationManager()

    var isLoginPresented = false
    private(set) var sessionGeneration = 0

    private init() {}

    /// Authelia peut répondre directement 401/403 ou rediriger silencieusement
    /// `URLSession` vers son portail, qui renvoie alors une page HTML avec un 200.
    func requiresAuthentication(originalURL: URL, response: URLResponse, data: Data) -> Bool {
        guard !AppConfig.useDevServer,
              originalURL.host == AppConfig.productionHost,
              let http = response as? HTTPURLResponse else { return false }

        if http.statusCode == 401 || http.statusCode == 403 { return true }
        // Redirection vers le portail, non suivie (cf. `AuthRedirectBlocker`).
        if (300..<400).contains(http.statusCode) { return true }

        if let finalHost = http.url?.host,
           finalHost != originalURL.host {
            return true
        }

        let contentType = http.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
        return contentType.contains("text/html") || data.startsWithHTMLDocument
    }

    /// Plusieurs requêtes peuvent échouer simultanément au chargement d'un écran.
    /// Le booléen observable les regroupe en une seule feuille de connexion.
    func presentLogin() {
        guard !isLoginPresented else { return }
        isLoginPresented = true
    }

    func authenticationSucceeded() {
        isLoginPresented = false
        sessionGeneration += 1
    }
}

/// Empêche `URLSession` de suivre la redirection d'Authelia vers son portail :
/// le 302 suffit à détecter la session manquante, inutile de télécharger la page
/// de connexion (et d'attendre) avant d'afficher la feuille.
nonisolated final class AuthRedirectBlocker: NSObject, URLSessionTaskDelegate {
    static let shared = AuthRedirectBlocker()

    // Variante à completion handler : la variante `async` fait planter le
    // compilateur Swift 6.4 (thunk Objective-C).
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        let from = task.originalRequest?.url?.host
        completionHandler(request.url?.host == from ? request : nil)
    }
}

private extension Data {
    var startsWithHTMLDocument: Bool {
        guard let prefix = String(data: self.prefix(256), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() else { return false }
        return prefix.hasPrefix("<!doctype html") || prefix.hasPrefix("<html")
    }
}
