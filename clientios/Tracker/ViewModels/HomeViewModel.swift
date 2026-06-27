//
//  HomeViewModel.swift
//  Tracker
//

import Foundation

/// Carte « Reprendre » : fiche TMDB résolue + progression de l'utilisateur.
struct ContinueWatchingItem: Identifiable {
    let id: Int
    let title: String
    let backdropPath: String?
    let posterPath: String?
    /// Prochain épisode à regarder, ex. « S2 · E5 ».
    let nextLabel: String
    /// Proportion d'épisodes vus (0…1), ou `nil` si le total est inconnu.
    let progress: Double?
}

@Observable
@MainActor
final class HomeViewModel {
    private(set) var trending: [TMDBSearchResult] = []
    private(set) var popularMovies: [TMDBSearchResult] = []
    private(set) var popularShows: [TMDBSearchResult] = []
    private(set) var continueWatching: [ContinueWatchingItem] = []
    private(set) var isLoading = false
    var errorMessage: String?

    /// Clés ("movie-123" / "tv-123") des médias déjà vus, pour le badge sur l'affiche.
    private(set) var seenKeys: Set<String> = []

    /// Média mis en avant dans le hero (première tendance de la semaine).
    var featured: TMDBSearchResult? { trending.first }

    private let tmdb = TMDBService.shared
    private let api = APIService.shared

    func load() async {
        // Premier affichage : tout charger. Sinon on rafraîchit les badges « vu » et
        // la section « Reprendre » (la progression a pu changer sur un autre écran).
        if trending.isEmpty {
            await reload()
        } else {
            await refreshSeenStates()
            await loadContinueWatching()
        }
    }

    func reload() async {
        isLoading = true
        errorMessage = nil
        do {
            async let trending = tmdb.trendingWeek()
            async let movies = tmdb.popularMovies()
            async let shows = tmdb.popularShows()
            self.trending = try await trending
            self.popularMovies = try await movies.results
            self.popularShows = try await shows.results
            await refreshSeenStates()
        } catch {
            if !error.isCancellation { errorMessage = error.localizedDescription }
        }
        await loadContinueWatching()
        isLoading = false
    }

    /// Charge les séries « en cours » (backend) puis résout leurs fiches TMDB en parallèle
    /// pour le titre, l'image paysage et le prochain épisode. Tolérant aux erreurs réseau.
    func loadContinueWatching() async {
        let inProgress = (try? await api.inProgressShows(forceRefresh: true)) ?? []
        guard !inProgress.isEmpty else {
            continueWatching = []
            return
        }

        continueWatching = await withTaskGroup(of: ContinueWatchingItem?.self) { group in
            for show in inProgress {
                group.addTask {
                    guard let detail = try? await TMDBService.shared.show(show.showTmdbId) else { return nil }
                    return Self.makeContinueItem(show: show, detail: detail)
                }
            }
            var byId: [Int: ContinueWatchingItem] = [:]
            for await item in group {
                if let item { byId[item.id] = item }
            }
            // On conserve l'ordre du backend (le plus récemment regardé d'abord).
            return inProgress.compactMap { byId[$0.showTmdbId] }
        }
    }

    nonisolated private static func makeContinueItem(show: InProgressShow, detail: TMDBShow) -> ContinueWatchingItem {
        let next = nextEpisode(seasons: detail.seasons,
                               lastSeason: show.lastSeasonNumber,
                               lastEpisode: show.lastEpisodeNumber)
        let total = detail.numberOfEpisodes ?? 0
        let progress: Double? = total > 0 ? min(1.0, Double(show.seenEpisodeCount) / Double(total)) : nil
        return ContinueWatchingItem(
            id: show.showTmdbId,
            title: detail.name,
            backdropPath: detail.backdropPath,
            posterPath: detail.posterPath ?? show.posterPath,
            nextLabel: "S\(next.season) · E\(next.episode)",
            progress: progress
        )
    }

    /// Prochain épisode : dernier vu + 1, ou première de la saison suivante si le
    /// dernier vu clôt sa saison. La saison 0 (spéciaux) est ignorée.
    nonisolated private static func nextEpisode(seasons: [TMDBSeasonSummary]?, lastSeason: Int, lastEpisode: Int) -> (season: Int, episode: Int) {
        let ordered = (seasons ?? [])
            .filter { $0.seasonNumber > 0 }
            .sorted { $0.seasonNumber < $1.seasonNumber }

        if let current = ordered.first(where: { $0.seasonNumber == lastSeason }),
           let count = current.episodeCount, lastEpisode < count {
            return (lastSeason, lastEpisode + 1)
        }
        if let nextSeason = ordered.first(where: { $0.seasonNumber > lastSeason && ($0.episodeCount ?? 0) > 0 }) {
            return (nextSeason.seasonNumber, 1)
        }
        return (lastSeason, lastEpisode + 1)
    }

    /// Recharge l'ensemble des médias vus depuis le backend (sans retoucher TMDB).
    func refreshSeenStates() async {
        seenKeys = await api.seenStateKeys(for: trending + popularMovies + popularShows)
    }

    func isSeen(_ result: TMDBSearchResult) -> Bool {
        seenKeys.contains("\(result.mediaType.rawValue)-\(result.id)")
    }
}
