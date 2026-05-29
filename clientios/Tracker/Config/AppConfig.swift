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
    static let tmdbApiKey = "REDACTED_TMDB_API_KEY"
    static let tmdbBaseURL = "https://api.themoviedb.org/3"
    static let tmdbLanguage = "fr-FR"
    static let tmdbImageBaseURL = "https://image.tmdb.org/t/p"

    // ── Backend Tracker (états utilisateur) ───────────────────────────────
    //
    // En simulateur, localhost pointe vers la machine hôte → le port du backend ASP.NET.
    // Sur un appareil physique, remplacer par l'IP locale de la machine.
    static let apiBaseURL = "http://localhost:5050/api"
}
