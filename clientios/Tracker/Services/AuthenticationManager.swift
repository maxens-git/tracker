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

private extension Data {
    var startsWithHTMLDocument: Bool {
        guard let prefix = String(data: self.prefix(256), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() else { return false }
        return prefix.hasPrefix("<!doctype html") || prefix.hasPrefix("<html")
    }
}
