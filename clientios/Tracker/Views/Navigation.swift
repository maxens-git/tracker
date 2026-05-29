//
//  Navigation.swift
//  Tracker
//
//  Destinations typées pour les NavigationStack de chaque onglet.
//

import SwiftUI

/// Destination "détail d'un média".
struct MediaRoute: Hashable {
    let tmdbId: Int
    let type: MediaType
}

/// Destination "détail d'une liste".
struct ListRoute: Hashable {
    /// Identifiant numérique ou alias système ("seen", "liked", "watchlist").
    let listId: String
    let title: String
}

extension View {
    /// Branche les destinations communes (média + liste) sur un NavigationStack.
    func trackerNavigationDestinations() -> some View {
        self
            .navigationDestination(for: MediaRoute.self) { route in
                MediaDetailView(tmdbId: route.tmdbId, type: route.type)
            }
            .navigationDestination(for: ListRoute.self) { route in
                ListDetailView(listId: route.listId, title: route.title)
            }
    }
}
