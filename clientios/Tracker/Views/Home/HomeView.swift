//
//  HomeView.swift
//  Tracker
//
//  Accueil « Liquid Glass » : la bannière occupe le haut de l'écran et passe
//  sous le titre flottant, puis les rangées horizontales défilent par-dessus le
//  fond sombre.
//

import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @AppStorage(AppStorageKeys.hideSeenItems) private var hideSeenItems = false

    var body: some View {
        scroller
    }

    /// Hauteur de la barre d'état / encoche.
    ///
    /// La page ignore la zone sûre en haut (la bannière doit monter jusqu'au
    /// bord de l'écran), donc SwiftUI ne décale plus le titre tout seul et un
    /// `GeometryReader` renvoie ici un inset nul : on lit la valeur sur la
    /// fenêtre.
    private var topInset: CGFloat {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .keyWindow?.safeAreaInsets.top ?? 0
    }

    private var scroller: some View {
        ScrollView {
            if viewModel.isLoading && viewModel.trending.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 120)
            } else {
                VStack(alignment: .leading, spacing: 30) {
                    if let featured = viewModel.featured, !(hideSeenItems && viewModel.isSeen(featured)) {
                        // Le titre est posé sur la bannière : il disparaît donc
                        // naturellement quand on fait défiler la page.
                        HeroView(item: featured)
                            .overlay(alignment: .topLeading) {
                                title.padding(.top, topInset + 6)
                            }
                    } else {
                        title.padding(.top, topInset + 6)
                    }
                    continueSection(viewModel.continueWatching)
                    section("Tendances", items: visible(viewModel.trending))
                    section("Films populaires", items: visible(viewModel.popularMovies))
                    section("Séries populaires", items: visible(viewModel.popularShows))
                }
                .padding(.bottom, 24)
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
    }

    /// Titre de l'écran, posé sur la bannière : il reste lisible grâce à son
    /// ombre, sans barre de navigation qui couperait l'image.
    private var title: some View {
        Text("Découvrir")
            .font(.display(28))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.5), radius: 14, x: 0, y: 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 22)
            .allowsHitTesting(false)
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
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader("En cours")
                    .padding(.horizontal, 22)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(items) { item in
                            NavigationLink(value: MediaRoute(tmdbId: item.id, type: .tv)) {
                                ContinueCard(item: item)
                                    .frame(width: 232)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 22)
                }
            }
        }
    }

    @ViewBuilder
    private func section(_ title: String, items: [TMDBSearchResult]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title)
                    .padding(.horizontal, 22)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(items) { item in
                            NavigationLink(value: MediaRoute(tmdbId: item.id, type: item.mediaType)) {
                                MediaCard(posterPath: item.posterPath,
                                          title: item.displayTitle,
                                          subtitle: item.year,
                                          seen: viewModel.isSeen(item))
                                    .frame(width: 124)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 22)
                }
            }
        }
    }
}

#Preview {
    NavigationStack { HomeView() }
}
