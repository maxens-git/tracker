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

            Tab("Activité", systemImage: "clock.arrow.circlepath") {
                NavigationStack {
                    ActivityView()
                        .trackerNavigationDestinations()
                }
            }

            Tab("Stats", systemImage: "chart.bar") {
                NavigationStack {
                    StatsView()
                        .trackerNavigationDestinations()
                }
            }
        }
    }
}

#Preview {
    RootView()
}
