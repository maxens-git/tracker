//
//  ReleaseCalendarViewModel.swift
//  Tracker
//

import Foundation

struct ReleaseCalendarItem: Identifiable, Hashable {
    let id: String
    let tmdbId: Int
    let type: MediaType
    let kind: String
    let title: String
    let subtitle: String
    let date: String
    let posterPath: String?
    /// Annoncé sur TMDB sans date publiée : affiché hors calendrier, dans la section « à venir ».
    var pending: Bool = false
}

@Observable
@MainActor
final class ReleaseCalendarViewModel {
    private let api = APIService.shared
    private let tmdb = TMDBService.shared

    private(set) var items: [ReleaseCalendarItem] = []
    /// Saisons/films annoncés sans date confirmée sur TMDB (ex. série « terminée » avec une saison à venir).
    private(set) var pendingItems: [ReleaseCalendarItem] = []
    private(set) var trackedCount = 0
    private(set) var isLoading = false
    var errorMessage: String?

    func load(forceRefresh: Bool = false) async {
        isLoading = true
        errorMessage = nil
        do {
            let tracked = try await api.trackedMedia(forceRefresh: forceRefresh)
            trackedCount = tracked.count
            var result: [ReleaseCalendarItem] = []
            for item in tracked {
                result += await releaseItems(for: item, forceRefresh: forceRefresh)
            }
            // Les items datés alimentent le calendrier/la liste ; ceux « à confirmer » leur section dédiée.
            items = result.filter { !$0.pending }.sorted { $0.date < $1.date }
            pendingItems = result.filter { $0.pending }
        } catch {
            if !error.isCancellation { errorMessage = error.localizedDescription }
        }
        isLoading = false
    }

    func remove(_ item: ReleaseCalendarItem) async {
        do {
            try await api.removeTrackedMedia(tmdbId: item.tmdbId, type: item.type)
            items.removeAll { $0.tmdbId == item.tmdbId && $0.type == item.type }
            pendingItems.removeAll { $0.tmdbId == item.tmdbId && $0.type == item.type }
            trackedCount = max(0, trackedCount - 1)
            Haptics.impact(.light)
        } catch {
            if !error.isCancellation { errorMessage = error.localizedDescription }
            Haptics.error()
        }
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
            // Film annoncé mais sans date publiée → section « à venir ».
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

            // Rien de concret à venir mais TMDB signale la série en production (saison
            // confirmée mais pas encore créée comme entrée TMDB) → carte « en préparation ».
            if datedSeasons.isEmpty && undatedSeasons.isEmpty && episodes.isEmpty && (show.inProduction ?? false) {
                deduped.append(inProductionPlaceholder(for: tracked, show: show))
            }
            return deduped
        }
    }

    /// Saisons annoncées mais sans date TMDB, plus récentes que la dernière saison déjà
    /// diffusée (cas typique : série marquée « terminée » dont une nouvelle saison arrive).
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

    /// Carte « saison en préparation » quand TMDB signale la série en production mais n'a
    /// pas encore créé d'entrée pour la prochaine saison (ex. The White Lotus S4 confirmée).
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

/// Numéro de la dernière saison déjà diffusée (date passée), ou 0 si aucune.
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

enum DateOnlyFormatter {
    static let input: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let output: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .medium
        return formatter
    }()

    static func date(from value: String) -> Date? { input.date(from: value) }
    static func display(_ value: String) -> String {
        guard let date = date(from: value) else { return value }
        return output.string(from: date)
    }
}
