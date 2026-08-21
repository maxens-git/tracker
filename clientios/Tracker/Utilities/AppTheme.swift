//
//  AppTheme.swift
//  Tracker
//
//  Clés @AppStorage partagées et préférence d'apparence : par défaut l'app
//  suit le mode clair / sombre du système, et les réglages permettent de la
//  forcer sur clair ou sombre.
//

import SwiftUI

/// Clé partagée pour @AppStorage entre le point d'entrée et les réglages.
enum AppStorageKeys {
    /// Masquer les médias déjà vus sur la page d'accueil.
    static let hideSeenItems = "hideSeenItems"
    /// Recherche & débridage activés : pilote la visibilité de l'onglet Torrents.
    static let torrentsEnabled = "torrentsEnabled"
    /// Utiliser le backend de développement (localhost) au lieu du serveur de prod.
    static let useDevServer = "useDevServer"
    /// Apparence de l'app : système, clair ou sombre (`AppAppearance`).
    static let appearance = "appearance"
}

/// Apparence choisie dans les réglages.
enum AppAppearance: String, CaseIterable, Identifiable {
    /// Suit le mode clair / sombre du système (comportement par défaut).
    case system
    case light
    case dark

    var id: String { rawValue }

    /// Schéma à imposer à la hiérarchie de vues, `nil` pour suivre le système.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var label: String {
        switch self {
        case .system: "Système"
        case .light: "Clair"
        case .dark: "Sombre"
        }
    }
}
