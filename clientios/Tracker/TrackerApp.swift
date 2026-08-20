//
//  TrackerApp.swift
//  Tracker
//
//  Created by Maxens Verron on 29/05/2026.
//

import SwiftUI

@main
struct TrackerApp: App {
    init() {
        // Agrandit le cache réseau partagé (affiches + fiches TMDB) avant toute requête.
        CacheManager.configure()
    }

    var body: some Scene {
        WindowGroup {
            // Ni thème forcé ni teinte imposée : l'app suit le mode clair /
            // sombre du système et l'asset `AccentColor`, comme une app native.
            RootView()
        }
    }
}
