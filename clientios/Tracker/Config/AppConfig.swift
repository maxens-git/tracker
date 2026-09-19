//
//  AppConfig.swift
//  Tracker
//
//  Configuration centrale : clés TMDB et URL du backend.
//  Pendant le refactoring (mai 2026), TMDB est appelé directement côté frontend ;
//  le backend ne stocke que les états utilisateur (vu / aimé / listes).
//

import Foundation

enum AppConfig {
    // ── TMDB (appelé directement par l'app) ───────────────────────────────
    //
    // Les trois valeurs ci-dessous sont surchargeables via les réglages (écran
    // Réglages → TMDB), persistés dans UserDefaults. À défaut de surcharge, on
    // retombe sur les valeurs compilées par défaut.
    static let defaultTmdbApiKey = "REDACTED_TMDB_API_KEY"
    static let defaultTmdbBaseURL = "https://api.themoviedb.org/3"
    static let defaultTmdbLanguage = "fr-FR"
    static let tmdbImageBaseURL = "https://image.tmdb.org/t/p"

    private enum TmdbKeys {
        static let apiKey = "tmdbApiKey"
        static let baseURL = "tmdbBaseUrl"
        static let language = "tmdbLanguage"
    }

    static var tmdbApiKey: String { override(TmdbKeys.apiKey) ?? defaultTmdbApiKey }
    static var tmdbBaseURL: String { override(TmdbKeys.baseURL) ?? defaultTmdbBaseURL }
    static var tmdbLanguage: String { override(TmdbKeys.language) ?? defaultTmdbLanguage }

    /// Mémorise (ou efface, si vide) les surcharges TMDB issues des réglages distants.
    static func setTmdbOverrides(apiKey: String?, baseURL: String?, language: String?) {
        store(TmdbKeys.apiKey, apiKey)
        store(TmdbKeys.baseURL, baseURL)
        store(TmdbKeys.language, language)
    }

    private static func override(_ key: String) -> String? {
        let value = UserDefaults.standard.string(forKey: key)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (value?.isEmpty ?? true) ? nil : value
    }

    private static func store(_ key: String, _ value: String?) {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            UserDefaults.standard.set(trimmed, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    // ── Backend Tracker (états utilisateur) ───────────────────────────────
    //
    // Deux environnements, basculables depuis Réglages → Serveur (persisté dans
    // UserDefaults). Le prod est la valeur par défaut. `apiBaseURL` étant lu à
    // chaque requête, la bascule prend effet sans redémarrage.
    //
    // En simulateur, localhost pointe vers la machine hôte → le port du backend ASP.NET.
    // Sur un appareil physique, remplacer par l'IP locale de la machine.
    static let apiProdURL = "https://tracker.maxens.org/api"
    static let apiDevURL = "http://localhost:5050/api"

    static var productionHost: String? { URL(string: apiProdURL)?.host }

    /// Une ressource JSON protégée : sans session, Authelia la redirige vers son
    /// portail ; après connexion, son retour sur ce domaine signale le succès.
    static var authenticationProbeURL: URL? {
        URL(string: apiProdURL + "/Settings")
    }

    /// Ne copie que les cookies du site de production : ceux de Tracker, ceux
    /// du domaine parent partagé et ceux du sous-domaine Authelia.
    static func acceptsAuthenticationCookie(_ cookie: HTTPCookie) -> Bool {
        guard let host = productionHost else { return false }
        let domain = cookie.domain.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let siteDomain = host.split(separator: ".").suffix(2).joined(separator: ".")
        return domain == siteDomain || domain.hasSuffix("." + siteDomain)
    }

    /// Vrai si l'utilisateur a basculé sur le serveur de développement (localhost).
    static var useDevServer: Bool {
        get { UserDefaults.standard.bool(forKey: AppStorageKeys.useDevServer) }
        set { UserDefaults.standard.set(newValue, forKey: AppStorageKeys.useDevServer) }
    }

    /// URL du backend selon l'environnement choisi dans les réglages.
    static var apiBaseURL: String { useDevServer ? apiDevURL : apiProdURL }
}
