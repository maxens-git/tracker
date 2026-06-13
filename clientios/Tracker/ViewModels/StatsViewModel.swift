//
//  StatsViewModel.swift
//  Tracker
//

import Foundation

/// Activité combinée (films + épisodes) d'une année, pour les graphiques empilés.
struct CombinedYearBucket: Identifiable, Hashable {
    let year: Int
    let movies: Int
    let episodes: Int
    var total: Int { movies + episodes }
    var id: Int { year }
}

/// Activité combinée (films + épisodes) d'un mois, pour les graphiques empilés.
struct CombinedMonthBucket: Identifiable, Hashable {
    let label: String
    let movies: Int
    let episodes: Int
    var total: Int { movies + episodes }
    var id: String { label }
}

@Observable
@MainActor
final class StatsViewModel {
    private(set) var stats: Stats?
    private(set) var isLoading = false
    var errorMessage: String?

    private let api = APIService.shared

    private static let monthsFR = ["Jan", "Fév", "Mar", "Avr", "Mai", "Juin",
                                   "Juil", "Août", "Sep", "Oct", "Nov", "Déc"]

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            stats = try await api.stats()
        } catch {
            if !error.isCancellation { errorMessage = error.localizedDescription }
        }
        isLoading = false
    }

    /// Activité par année (films + épisodes fusionnés), triée par année croissante.
    var byYear: [CombinedYearBucket] {
        guard let stats else { return [] }
        var map: [Int: (movies: Int, episodes: Int)] = [:]
        for b in stats.moviesSeenByYear { map[b.year, default: (0, 0)].movies = b.count }
        for b in stats.episodesSeenByYear { map[b.year, default: (0, 0)].episodes = b.count }
        return map.map { CombinedYearBucket(year: $0.key, movies: $0.value.movies, episodes: $0.value.episodes) }
            .sorted { $0.year < $1.year }
    }

    /// Activité des 12 derniers mois (films + épisodes fusionnés).
    var byMonth: [CombinedMonthBucket] {
        guard let stats else { return [] }
        let calendar = Calendar.current
        let now = Date()
        var buckets: [CombinedMonthBucket] = []

        for i in stride(from: 11, through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .month, value: -i, to: now) else { continue }
            let comps = calendar.dateComponents([.year, .month], from: date)
            guard let y = comps.year, let m = comps.month else { continue }
            let movies = stats.moviesSeenByMonth.first { $0.year == y && $0.month == m }?.count ?? 0
            let episodes = stats.episodesSeenByMonth.first { $0.year == y && $0.month == m }?.count ?? 0
            buckets.append(CombinedMonthBucket(label: Self.monthsFR[m - 1], movies: movies, episodes: episodes))
        }
        return buckets
    }

    /// Temps total formaté en jours / heures / minutes (comme le client web).
    func formatRuntime(_ minutes: Int) -> String {
        guard minutes > 0 else { return "—" }
        let days = minutes / 1440
        let hours = (minutes % 1440) / 60
        let mins = minutes % 60
        if days > 0 { return "\(days)j \(hours)h" }
        if hours > 0 { return "\(hours)h \(mins)min" }
        return "\(mins)min"
    }
}
