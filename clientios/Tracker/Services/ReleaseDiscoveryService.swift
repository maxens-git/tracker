//
//  ReleaseDiscoveryService.swift
//  Tracker
//
//  Source commune des sorties affichées dans le calendrier et programmées en
//  notifications locales.
//

import Foundation

struct ReleaseDiscoveryResult {
    let items: [ReleaseCalendarItem]
    let trackedCount: Int
}

@MainActor
final class ReleaseDiscoveryService {
    static let shared = ReleaseDiscoveryService()

    private let api = APIService.shared
    private let tmdb = TMDBService.shared

    private init() {}

    func discover(forceRefresh: Bool = false) async throws -> ReleaseDiscoveryResult {
        let tracked = try await api.trackedMedia(forceRefresh: forceRefresh)
        var result: [ReleaseCalendarItem] = []
        for item in tracked {
            result += await releaseItems(for: item, forceRefresh: forceRefresh)
        }
        return ReleaseDiscoveryResult(items: result, trackedCount: tracked.count)
    }

    private func releaseItems(for tracked: TrackedMedia, forceRefresh: Bool) async -> [ReleaseCalendarItem] {
        switch tracked.type {
        case .movie:
            guard let movie = try? await tmdb.movie(tracked.tmdbId, forceRefresh: forceRefresh) else { return [] }
            if isFuture(movie.releaseDate) {
                return [ReleaseCalendarItem(
                    id: "movie-\(movie.id)-\(movie.releaseDate ?? "")",
                    tmdbId: movie.id,
                    type: .movie,
                    kind: "Film",
                    title: movie.title,
                    subtitle: "Sortie du film",
                    date: movie.releaseDate ?? "",
                    posterPath: movie.posterPath ?? tracked.posterPath)]
            }
            guard movie.releaseDate == nil else { return [] }
            return [ReleaseCalendarItem(
                id: "movie-\(movie.id)-pending",
                tmdbId: movie.id,
                type: .movie,
                kind: "Film",
                title: movie.title,
                subtitle: "Sortie à confirmer",
                date: "",
                posterPath: movie.posterPath ?? tracked.posterPath,
                pending: true)]

        case .tv:
            guard let show = try? await tmdb.show(tracked.tmdbId, forceRefresh: forceRefresh) else { return [] }
            let datedSeasons = show.seasons?
                .filter { $0.seasonNumber > 0 && isFuture($0.airDate) }
                .map { season in
                    ReleaseCalendarItem(
                        id: "tv-\(show.id)-season-\(season.seasonNumber)-\(season.airDate ?? "")",
                        tmdbId: show.id,
                        type: .tv,
                        kind: "Saison",
                        title: show.name,
                        subtitle: "\(season.name) · \(season.episodeCount ?? 0) épisodes",
                        date: season.airDate ?? "",
                        posterPath: season.posterPath ?? show.posterPath ?? tracked.posterPath)
                } ?? []

            let undatedSeasons = self.undatedSeasons(for: tracked, show: show)
            let seasonsToInspect = (show.seasons ?? [])
                .filter(shouldInspectSeason)
                .suffix(3)

            // Chaque épisode conserve son propre item et recevra donc sa propre
            // notification, y compris lorsque plusieurs épisodes sortent le même jour.
            var episodes: [ReleaseCalendarItem] = []
            for season in seasonsToInspect {
                if let detail = try? await tmdb.season(showId: show.id, seasonNumber: season.seasonNumber) {
                    episodes += detail.episodes
                        .filter { isFuture($0.airDate) }
                        .map { episode in
                            ReleaseCalendarItem(
                                id: "tv-\(show.id)-s\(episode.seasonNumber)-e\(episode.episodeNumber)-\(episode.airDate ?? "")",
                                tmdbId: show.id,
                                type: .tv,
                                kind: "Épisode",
                                title: show.name,
                                subtitle: "S\(String(format: "%02d", episode.seasonNumber))E\(String(format: "%02d", episode.episodeNumber)) - \(episode.name)",
                                date: episode.airDate ?? "",
                                posterPath: show.posterPath ?? tracked.posterPath)
                        }
                }
            }

            var seen = Set<String>()
            var deduped = (datedSeasons + undatedSeasons + episodes).filter { seen.insert($0.id).inserted }
            if datedSeasons.isEmpty && undatedSeasons.isEmpty && episodes.isEmpty && (show.inProduction ?? false) {
                deduped.append(inProductionPlaceholder(for: tracked, show: show))
            }
            return deduped
        }
    }

    private func undatedSeasons(for tracked: TrackedMedia, show: TMDBShow) -> [ReleaseCalendarItem] {
        let lastAired = lastAiredSeason(show)
        return (show.seasons ?? [])
            .filter { $0.seasonNumber > 0 && $0.airDate == nil && $0.seasonNumber > lastAired }
            .map { season in
                ReleaseCalendarItem(
                    id: "tv-\(show.id)-season-\(season.seasonNumber)-pending",
                    tmdbId: show.id,
                    type: .tv,
                    kind: "Saison",
                    title: show.name,
                    subtitle: "\(season.name) · date à confirmer",
                    date: "",
                    posterPath: season.posterPath ?? show.posterPath ?? tracked.posterPath,
                    pending: true)
            }
    }

    private func inProductionPlaceholder(for tracked: TrackedMedia, show: TMDBShow) -> ReleaseCalendarItem {
        let nextNumber = lastAiredSeason(show) + 1
        return ReleaseCalendarItem(
            id: "tv-\(show.id)-inproduction",
            tmdbId: show.id,
            type: .tv,
            kind: "Saison",
            title: show.name,
            subtitle: "Saison \(nextNumber) en préparation · date à confirmer",
            date: "",
            posterPath: show.posterPath ?? tracked.posterPath,
            pending: true)
    }
}

private func lastAiredSeason(_ show: TMDBShow) -> Int {
    (show.seasons ?? [])
        .filter { $0.seasonNumber > 0 && $0.airDate != nil && !isFuture($0.airDate) }
        .map { $0.seasonNumber }
        .max() ?? 0
}

private func isFuture(_ value: String?) -> Bool {
    guard let value, let date = DateOnlyFormatter.date(from: value) else { return false }
    return date >= Calendar.current.startOfDay(for: Date())
}

private func shouldInspectSeason(_ season: TMDBSeasonSummary) -> Bool {
    guard season.seasonNumber > 0 else { return false }
    guard let airDate = season.airDate, let date = DateOnlyFormatter.date(from: airDate) else { return true }
    let min = Calendar.current.date(byAdding: .day, value: -90, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    return date >= min
}
