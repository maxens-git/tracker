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
                HomeLoadingView()
                    .contentColumn()
            } else {
                VStack(alignment: .leading, spacing: 28) {
                    if let featured = visible(viewModel.trending).first {
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
                .contentColumn()
            }
        }
        .background(Color.appBackground)
        .navigationTitle("Découvrir")
        .task { await viewModel.load() }
        .refreshable { await viewModel.reload() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Toggle(isOn: $hideSeenItems) {
                        Label("Masquer les contenus vus", systemImage: "eye.slash")
                    }
                } label: {
                    Label("Options d'affichage",
                          systemImage: hideSeenItems
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "line.3.horizontal.decrease.circle")
                }
            }
        }
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
                SectionHeader("Reprendre")
                    .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(items) { item in
                            let route = MediaRoute(tmdbId: item.id, type: .tv, source: "continue")
                            NavigationLink(value: route) {
                                ContinueCard(item: item)
                                    .frame(width: 252)
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
                                    .frame(width: 132)
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

/// État de chargement qui conserve la structure finale de l'accueil. Il évite
/// le grand écran vide autour d'un spinner et réduit le saut de mise en page à
/// l'arrivée des images.
private struct HomeLoadingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .fill(Color.appPlaceholder)
                .aspectRatio(4.0 / 3.0, contentMode: .fit)
                .padding(.horizontal)

            ForEach(0..<3, id: \.self) { section in
                VStack(alignment: .leading, spacing: 12) {
                    skeletonLine(width: section == 0 ? 112 : 150, height: 18)
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(0..<3, id: \.self) { _ in
                                VStack(alignment: .leading, spacing: 7) {
                                    RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                                        .fill(Color.appPlaceholder)
                                        .frame(width: 132, height: 198)
                                        .clipShape(
                                            RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                                        )
                                    skeletonLine(width: 104, height: 11)
                                    skeletonLine(width: 48, height: 9)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .scrollDisabled(true)
                    .clipped()
                }
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 24)
        .opacity(pulsing ? 0.58 : 1)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                   value: pulsing)
        .onAppear { pulsing = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Chargement des recommandations")
    }

    private func skeletonLine(width: CGFloat, height: CGFloat) -> some View {
        Capsule()
            .fill(Color.appPlaceholder)
            .frame(width: width, height: height)
    }
}

#Preview {
    NavigationStack { HomeView() }
}
