//
//  RootView.swift
//  Tracker
//
//  Conteneur principal : barre d'onglets (Accueil / Recherche / Listes / Stats).
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
    }
}

#Preview {
    RootView()
}
