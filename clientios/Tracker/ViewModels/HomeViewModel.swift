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

    /// Média mis en avant dans le hero (première tendance de la semaine).
    var featured: TMDBSearchResult? { trending.first }

    private let tmdb = TMDBService.shared

    func load() async {
        guard trending.isEmpty else { return }
        await reload()
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
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
