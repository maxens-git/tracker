//
//  Navigation.swift
//  Tracker
//
//  Destinations typées pour les NavigationStack de chaque onglet, et la
//  plomberie de la transition zoom d'iOS 26 : chaque pile d'onglet possède un
//  `Namespace` (posé dans l'environnement), les vignettes se déclarent sources
//  (`zoomSource`) et la destination s'ouvre en zoom depuis la vignette tapée —
//  le geste des fiches de l'App Store.
//

import SwiftUI

/// Destination "détail d'un média".
struct MediaRoute: Hashable {
    let tmdbId: Int
    let type: MediaType
    /// Vignette d'origine, pour distinguer deux affiches du même média dans une
    /// même pile (un film peut être à la fois « à la une » et dans une rangée
    /// de l'accueil, ou dans deux sections de la liste des sorties). L'id de la
    /// transition zoom étant la route elle-même, sans ce discriminant les
    /// vignettes en double partagent le même id et l'animation part toujours de
    /// la première. Ignoré à l'ouverture de la fiche.
    var source: String = ""
}

/// Destination "détail d'une liste".
struct ListRoute: Hashable {
    /// Identifiant numérique ou alias système ("seen", "liked", "watchlist").
    let listId: String
    let title: String
}

/// Destination "détail d'une personne" (acteur / équipe).
struct PersonRoute: Hashable {
    let personId: Int
}

// MARK: - Namespace de la transition zoom

private struct ZoomNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    /// Namespace partagé entre les vignettes (sources) et les destinations
    /// d'une même pile de navigation, pour la transition zoom.
    var zoomNamespace: Namespace.ID? {
        get { self[ZoomNamespaceKey.self] }
        set { self[ZoomNamespaceKey.self] = newValue }
    }
}

extension View {
    /// Déclare la vue comme source de la transition zoom vers `route`.
    /// Sans namespace dans l'environnement, ne change rien (poussée standard).
    @ViewBuilder
    func zoomSource(_ route: some Hashable, in namespace: Namespace.ID?) -> some View {
        if let namespace {
            matchedTransitionSource(id: route, in: namespace)
        } else {
            self
        }
    }

    /// Ouvre la destination en zoom depuis la source `route` correspondante.
    @ViewBuilder
    fileprivate func zoomDestination(for route: some Hashable, in namespace: Namespace.ID?) -> some View {
        if let namespace {
            navigationTransition(.zoom(sourceID: route, in: namespace))
        } else {
            self
        }
    }

    /// Branche les destinations communes (média / liste / personne) sur un
    /// NavigationStack, avec la transition zoom quand un namespace est fourni.
    func trackerNavigationDestinations(zoom namespace: Namespace.ID? = nil) -> some View {
        self
            .navigationDestination(for: MediaRoute.self) { route in
                MediaDetailView(tmdbId: route.tmdbId, type: route.type)
                    .zoomDestination(for: route, in: namespace)
            }
            .navigationDestination(for: ListRoute.self) { route in
                ListDetailView(listId: route.listId, title: route.title)
            }
            .navigationDestination(for: PersonRoute.self) { route in
                PersonView(personId: route.personId)
                    .zoomDestination(for: route, in: namespace)
            }
    }
}
