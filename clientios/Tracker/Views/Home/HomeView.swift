//
//  HomeView.swift
//  Tracker
//
//  Accueil : une carte « à la une » puis des rangées horizontales, sous un
//  grand titre de navigation standard — la structure des écrans de découverte
//  d'iOS (App Store, TV, Musique).
//

import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @AppStorage(AppStorageKeys.hideSeenItems) private var hideSeenItems = false
    @Environment(\.zoomNamespace) private var zoomNamespace

    var body: some View {
        ScrollView {
            if viewModel.isLoading && viewModel.trending.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
            } else {
                VStack(alignment: .leading, spacing: 28) {
                    if let featured = viewModel.featured, !(hideSeenItems && viewModel.isSeen(featured)) {
                        HeroView(item: featured)
                            .padding(.horizontal)
                    }
                    continueSection(viewModel.continueWatching)
                    section("Tendances", items: visible(viewModel.trending))
                    section("Films populaires", items: visible(viewModel.popularMovies))
                    section("Séries populaires", items: visible(viewModel.popularShows))
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Découvrir")
        .task { await viewModel.load() }
        .refreshable { await viewModel.reload() }
        .overlay {
            if let error = viewModel.errorMessage, viewModel.trending.isEmpty {
                ContentUnavailableView("Erreur", systemImage: "wifi.slash", description: Text(error))
            }
        }
    }

    /// Filtre les médias déjà vus si l'option correspondante est activée dans les réglages.
    private func visible(_ items: [TMDBSearchResult]) -> [TMDBSearchResult] {
        guard hideSeenItems else { return items }
        return items.filter { !viewModel.isSeen($0) }
    }

    /// Rangée « En cours » : séries commencées, en cartes paysage.
    @ViewBuilder
    private func continueSection(_ items: [ContinueWatchingItem]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("En cours")
                    .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(items) { item in
                            let route = MediaRoute(tmdbId: item.id, type: .tv, source: "continue")
                            NavigationLink(value: route) {
                                ContinueCard(item: item)
                                    .frame(width: 228)
                                    .zoomSource(route, in: zoomNamespace)
                            }
                            .buttonStyle(.pressableCard)
                            .edgeFade()
                        }
                    }
                    .padding(.horizontal)
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
            }
        }
    }

    @ViewBuilder
    private func section(_ title: String, items: [TMDBSearchResult]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title)
                    .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(items) { item in
                            let route = MediaRoute(tmdbId: item.id, type: item.mediaType, source: title)
                            NavigationLink(value: route) {
                                MediaCard(posterPath: item.posterPath,
                                          title: item.displayTitle,
                                          subtitle: item.year,
                                          seen: viewModel.isSeen(item))
                                    .frame(width: 120)
                                    .zoomSource(route, in: zoomNamespace)
                            }
                            .buttonStyle(.pressableCard)
                            .edgeFade()
                        }
                    }
                    .padding(.horizontal)
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
            }
        }
    }
}

#Preview {
    NavigationStack { HomeView() }
}
