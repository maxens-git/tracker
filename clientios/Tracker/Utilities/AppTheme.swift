//
//  AppTheme.swift
//  Tracker
//
//  Clés @AppStorage partagées et préférence d'apparence : par défaut l'app
//  suit le mode clair / sombre du système, et les réglages permettent de la
//  forcer sur clair ou sombre.
//

import Foundation
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
    /// Canal de notification choisi sur cet appareil.
    static let notificationDelivery = "notificationDelivery"
}

/// Canal utilisé pour les alertes de sorties. Le choix Tracker est propre à
/// l'appareil, puisque l'autorisation et les requêtes locales appartiennent à iOS.
enum NotificationDelivery: String, CaseIterable, Identifiable {
    case disabled
    case ntfy
    case tracker

    var id: String { rawValue }

    var label: String {
        switch self {
        case .disabled: "Désactivées"
        case .ntfy: "ntfy"
        case .tracker: "Tracker"
        }
    }
}

enum NotificationPreferences {
    /// `nil` distingue une installation existante (à migrer depuis NTFY) d'un
    /// choix explicite « désactivées ».
    static var savedDelivery: NotificationDelivery? {
        guard let raw = UserDefaults.standard.string(forKey: AppStorageKeys.notificationDelivery) else {
            return nil
        }
        return NotificationDelivery(rawValue: raw)
    }

    static var delivery: NotificationDelivery {
        get { savedDelivery ?? .disabled }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: AppStorageKeys.notificationDelivery) }
    }
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
