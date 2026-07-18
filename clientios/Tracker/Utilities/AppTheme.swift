//
//  AppTheme.swift
//  Tracker
//
//  Préférence de thème de l'application (système / clair / sombre),
//  persistée dans UserDefaults via @AppStorage.
//

import SwiftUI

/// Clé partagée pour @AppStorage entre le point d'entrée et les réglages.
enum AppStorageKeys {
    static let theme = "appTheme"
    /// Masquer les médias déjà vus sur la page d'accueil.
    static let hideSeenItems = "hideSeenItems"
    /// Recherche & débridage activés : pilote la visibilité de l'onglet Torrents.
    static let torrentsEnabled = "torrentsEnabled"
}

/// Préférence de thème choisie par l'utilisateur.
enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    /// Libellé affiché dans les réglages.
    var label: String {
        switch self {
        case .system: return "Système"
        case .light:  return "Clair"
        case .dark:   return "Sombre"
        }
    }

    /// ColorScheme à forcer ; `nil` = suit le réglage système.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}
