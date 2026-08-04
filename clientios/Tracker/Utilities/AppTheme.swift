//
//  AppTheme.swift
//  Tracker
//
//  Clés @AppStorage partagées. L'app est verrouillée en mode sombre
//  (cf. `TrackerApp`) : il n'y a plus de préférence de thème.
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
}
