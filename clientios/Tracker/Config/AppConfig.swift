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
    // En simulateur, localhost pointe vers la machine hôte → le port du backend ASP.NET.
    // Sur un appareil physique, remplacer par l'IP locale de la machine.
    static let apiBaseURL = "https://tracker.maxens.org/api"
    //static let apiBaseURL = "http://localhost:5050/api"
}
