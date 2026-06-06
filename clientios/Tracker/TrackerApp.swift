//
//  TrackerApp.swift
//  Tracker
//
//  Created by Maxens Verron on 29/05/2026.
//

import SwiftUI

@main
struct TrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ThemedRootView()
        }
    }
}

/// Conteneur racine qui applique la préférence de thème.
///
/// Le `@AppStorage` est placé ici (dans une `View`) et non dans le `struct App` :
/// dans `App`, le changement de valeur ne redéclenche pas toujours le recalcul de
/// la scène, ce qui fige `preferredColorScheme` sur sa valeur initiale.
private struct ThemedRootView: View {
    @AppStorage(AppStorageKeys.theme) private var theme: AppTheme = .system

    var body: some View {
        RootView()
            .preferredColorScheme(theme.colorScheme)
    }
}
