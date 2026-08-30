//
//  TrackerApp.swift
//  Tracker
//
//  Created by Maxens Verron on 29/05/2026.
//

import SwiftUI

@main
struct TrackerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// Apparence choisie dans les réglages ; `.system` laisse iOS décider.
    @AppStorage(AppStorageKeys.appearance) private var appearance = AppAppearance.system

    init() {
        // Agrandit le cache réseau partagé (affiches + fiches TMDB) avant toute requête.
        CacheManager.configure()
    }

    var body: some Scene {
        WindowGroup {
            // Aucune teinte imposée (asset `AccentColor`) et, par défaut, le
            // mode clair / sombre du système — sauf si les réglages le forcent.
            RootView()
                .preferredColorScheme(appearance.colorScheme)
        }
    }
}
