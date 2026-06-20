//
//  HomeView.swift
//  Tracker
//

import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @State private var showingSettings = false
    @AppStorage(AppStorageKeys.hideSeenItems) private var hideSeenItems = false

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
                    }
                    section("Tendances de la semaine", items: visible(viewModel.trending))
                    section("Films populaires", items: visible(viewModel.popularMovies))
                    section("Séries populaires", items: visible(viewModel.popularShows))
                }
                .padding(.bottom)
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .ignoresSafeArea(edges: .top)
        .task { await viewModel.load() }
        .refreshable { await viewModel.reload() }
        .overlay {
            if let error = viewModel.errorMessage, viewModel.trending.isEmpty {
                ContentUnavailableView("Erreur", systemImage: "wifi.slash", description: Text(error))
            }
        }
        // Bouton réglages flottant : la barre de navigation est masquée sur l'accueil,
        // on superpose donc le bouton en haut à droite.
        .overlay(alignment: .topTrailing) {
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
                    .environment(\.colorScheme, .dark)
                    .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
            }
            .padding(.top, 12)
            .padding(.trailing, 16)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }

    /// Filtre les médias déjà vus si l'option correspondante est activée dans les réglages.
    private func visible(_ items: [TMDBSearchResult]) -> [TMDBSearchResult] {
        guard hideSeenItems else { return items }
        return items.filter { !viewModel.isSeen($0) }
    }

    @ViewBuilder
    private func section(_ title: String, items: [TMDBSearchResult]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.display(20))
                    .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(items) { item in
                            NavigationLink(value: MediaRoute(tmdbId: item.id, type: item.mediaType)) {
                                MediaCard(posterPath: item.posterPath,
                                          title: item.displayTitle,
                                          subtitle: item.year,
                                          seen: viewModel.isSeen(item))
                                    .frame(width: 120)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

#Preview {
    NavigationStack { HomeView() }
}
