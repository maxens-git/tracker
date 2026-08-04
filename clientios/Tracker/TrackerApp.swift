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
        // Titres de navigation en police d'affichage « arrondie » (cf. Seance).
        AppAppearance.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(.appAccent)
                // L'app est pensée « salle obscure » : elle reste en mode sombre
                // quel que soit le réglage système.
                .preferredColorScheme(.dark)
        }
    }
}
