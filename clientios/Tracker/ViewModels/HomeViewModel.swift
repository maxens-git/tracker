//
//  HomeViewModel.swift
//  Tracker
//

import Foundation

@Observable
@MainActor
final class HomeViewModel {
    private(set) var trending: [TMDBSearchResult] = []
    private(set) var popularMovies: [TMDBSearchResult] = []
    private(set) var popularShows: [TMDBSearchResult] = []
    private(set) var isLoading = false
    var errorMessage: String?

    /// Clés ("movie-123" / "tv-123") des médias déjà vus, pour le badge sur l'affiche.
    private(set) var seenKeys: Set<String> = []

    /// Média mis en avant dans le hero (première tendance de la semaine).
    var featured: TMDBSearchResult? { trending.first }

    private let tmdb = TMDBService.shared
    private let api = APIService.shared

    func load() async {
        // Premier affichage : tout charger. Sinon on rafraîchit seulement les badges
        // « vu » (peu coûteux) pour refléter ce qui a changé depuis un autre écran.
        if trending.isEmpty {
            await reload()
        } else {
            await refreshSeenStates()
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
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Recharge l'ensemble des médias vus depuis le backend (sans retoucher TMDB).
    func refreshSeenStates() async {
        seenKeys = await api.seenStateKeys(for: trending + popularMovies + popularShows)
    }

    func isSeen(_ result: TMDBSearchResult) -> Bool {
        seenKeys.contains("\(result.mediaType.rawValue)-\(result.id)")
    }
}
