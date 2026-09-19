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
    /// Onglet affiché. Nécessaire pour distinguer l'onglet Recherche : c'est la barre
    /// d'onglets qui porte son champ de saisie, elle ne doit donc pas s'y replier.
    @State private var selection: AppTab = .home
    @State private var authentication = AuthenticationManager.shared

    private enum AppTab {
        case home, lists, releases, more, search
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab("Accueil", systemImage: "house", value: AppTab.home) {
                TabStack { HomeView() }
            }

            Tab("Listes", systemImage: "list.bullet", value: AppTab.lists) {
                TabStack { ListsView() }
            }

            Tab("Sorties", systemImage: "calendar", value: AppTab.releases) {
                TabStack { ReleaseCalendarView() }
            }

            Tab("Plus", systemImage: "ellipsis", value: AppTab.more) {
                TabStack { MoreView() }
            }

            // Déclaré en dernier, comme il est rendu : `role: .search` détache cet
            // onglet des autres et lui donne l'affordance de recherche dédiée de
            // la barre iOS 26, au lieu d'un cinquième onglet indifférencié.
            Tab("Recherche", systemImage: "magnifyingglass", value: AppTab.search, role: .search) {
                TabStack { SearchView() }
            }
        }
        // Une nouvelle identité reconstruit les écrans et relance leurs `.task`,
        // y compris les requêtes qui avaient découvert l'expiration de session.
        .id(authentication.sessionGeneration)
        // La barre se replie au défilement pour laisser respirer les affiches — sauf sur
        // l'onglet Recherche, où elle contient le champ de saisie : un historique plus haut
        // que l'écran le faisait disparaître, et il fallait re-glisser vers le bas.
        .tabBarMinimizeBehavior(selection == .search ? .never : .onScrollDown)
        // Applique au lancement la config TMDB éventuellement surchargée dans les
        // réglages (clé / URL / langue), pour que l'accueil l'utilise directement.
        .task {
            if let settings = try? await APIService.shared.settings() {
                AppConfig.setTmdbOverrides(
                    apiKey: settings.tmdbApiKey,
                    baseURL: settings.tmdbBaseUrl,
                    language: settings.tmdbLanguage)
                if NotificationPreferences.delivery == .tracker {
                    _ = try? await NotificationSyncService.shared.sync(settings: settings)
                }
            }
        }
        .sheet(isPresented: $authentication.isLoginPresented) {
            AuthenticationView()
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
