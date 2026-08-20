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
                TabStack { HomeView() }
            }

            Tab("Listes", systemImage: "list.bullet") {
                TabStack { ListsView() }
            }

            Tab("Sorties", systemImage: "calendar") {
                TabStack { ReleaseCalendarView() }
            }

            Tab("Plus", systemImage: "ellipsis") {
                TabStack { MoreView() }
            }

            // Déclaré en dernier, comme il est rendu : `role: .search` détache cet
            // onglet des autres et lui donne l'affordance de recherche dédiée de
            // la barre iOS 26, au lieu d'un cinquième onglet indifférencié.
            Tab("Recherche", systemImage: "magnifyingglass", role: .search) {
                TabStack { SearchView() }
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

/// Pile de navigation d'un onglet : porte le `Namespace` de la transition zoom
/// (partagé via l'environnement entre les vignettes et leurs destinations) et
/// branche les destinations communes.
private struct TabStack<Content: View>: View {
    @Namespace private var zoomNamespace
    @ViewBuilder let content: () -> Content

    var body: some View {
        NavigationStack {
            content()
                .trackerNavigationDestinations(zoom: zoomNamespace)
        }
        .environment(\.zoomNamespace, zoomNamespace)
    }
}

#Preview {
    RootView()
}
