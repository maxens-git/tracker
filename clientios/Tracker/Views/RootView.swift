//
//  RootView.swift
//  Tracker
//
//  Conteneur principal : barre d'onglets (Accueil / Recherche / Listes / Stats).
//
//  La barre d'onglets est la capsule de verre native d'iOS 26 : elle flotte
//  au-dessus du contenu et se réduit au défilement vers le bas pour laisser
//  respirer les affiches (cf. maquette Liquid Glass).
//

import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            Tab("Accueil", systemImage: "house") {
                NavigationStack {
                    HomeView()
                        .trackerNavigationDestinations()
                }
            }

            Tab("Recherche", systemImage: "magnifyingglass") {
                NavigationStack {
                    SearchView()
                        .trackerNavigationDestinations()
                }
            }

            Tab("Listes", systemImage: "list.bullet") {
                NavigationStack {
                    ListsView()
                        .trackerNavigationDestinations()
                }
            }

            Tab("Sorties", systemImage: "calendar") {
                NavigationStack {
                    ReleaseCalendarView()
                        .trackerNavigationDestinations()
                }
            }

            Tab("Plus", systemImage: "ellipsis") {
                NavigationStack {
                    MoreView()
                        .trackerNavigationDestinations()
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        // Applique au lancement la config TMDB éventuellement surchargée dans les
        // réglages (clé / URL / langue), pour que l'accueil l'utilise directement.
        .task {
            if let settings = try? await APIService.shared.settings() {
                AppConfig.setTmdbOverrides(
                    apiKey: settings.tmdbApiKey,
                    baseURL: settings.tmdbBaseUrl,
                    language: settings.tmdbLanguage)
            }
        }
    }
}

#Preview {
    RootView()
}
