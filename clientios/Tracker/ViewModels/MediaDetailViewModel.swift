//
//  MediaDetailViewModel.swift
//  Tracker
//

import Foundation

@Observable
@MainActor
final class MediaDetailViewModel {
    let tmdbId: Int
    let type: MediaType

    private(set) var movie: TMDBMovie?
    private(set) var show: TMDBShow?
    private(set) var state: UserState?
    private(set) var similar: [TMDBSearchResult] = []
    private(set) var cast: [TMDBCastMember] = []
    private(set) var crew: [TMDBCrewMember] = []
    private(set) var trailers: [TMDBVideo] = []
    private(set) var isLoading = false
    var errorMessage: String?

    // ── Saisons / épisodes (séries) ───────────────────────────────────────
    /// Clés "saison-épisode" des épisodes marqués vus.
    private(set) var episodesSeen: Set<String> = []
    /// Épisodes chargés par numéro de saison (chargement paresseux).
    private(set) var seasonEpisodes: [Int: [TMDBEpisode]] = [:]
    private(set) var loadingSeasons: Set<Int> = []
    var expandedSeason: Int?

    /// Saisons réelles (hors saison 0 = bonus / spéciaux).
    var seasons: [TMDBSeasonSummary] {
        (show?.seasons ?? []).filter { $0.seasonNumber > 0 }
    }

    private let tmdb = TMDBService.shared
    private let api = APIService.shared

    init(tmdbId: Int, type: MediaType) {
        self.tmdbId = tmdbId
        self.type = type
    }

    // ── Champs dérivés pour l'UI ──────────────────────────────────────────

    var title: String { movie?.title ?? show?.name ?? "" }
    var overview: String? { movie?.overview ?? show?.overview }
    var posterPath: String? { movie?.posterPath ?? show?.posterPath }
    var backdropPath: String? { movie?.backdropPath ?? show?.backdropPath }
    var rating: Double? { movie?.voteAverage ?? show?.voteAverage }
    var genres: [TMDBGenre] { movie?.genres ?? show?.genres ?? [] }

    var seen: Bool { state?.seen ?? false }
    var liked: Bool { state?.liked ?? false }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            switch type {
            case .movie: movie = try await tmdb.movie(tmdbId)
            case .tv: show = try await tmdb.show(tmdbId)
            }
            state = try await api.states(tmdbIds: [tmdbId], type: type).first
            if type == .tv {
                let seen = try await api.showEpisodes(showTmdbId: tmdbId)
                episodesSeen = Set(seen.filter(\.seen).map { epKey($0.seasonNumber, $0.episodeNumber) })
                await syncShowSeen()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        // Contenus secondaires : un échec ne doit pas masquer le détail.
        async let similar = tmdb.similar(tmdbId, type: type)
        async let credits = tmdb.credits(tmdbId, type: type)
        async let videos = tmdb.videos(tmdbId, type: type)

        self.similar = (try? await similar) ?? []

        if let credits = try? await credits {
            cast = Array(credits.cast.prefix(12))
            crew = topCrew(from: credits.crew)
        }
        if let videos = try? await videos {
            trailers = filterTrailers(videos.results)
        }

        isLoading = false
    }

    /// Sélectionne les bandes-annonces : YouTube, type Trailer/Teaser,
    /// langue française d'abord puis anglaise (max 6), comme le client web.
    private func filterTrailers(_ videos: [TMDBVideo]) -> [TMDBVideo] {
        func matches(_ v: TMDBVideo, lang: String) -> Bool {
            v.language == lang && v.site == "YouTube" && (v.type == "Trailer" || v.type == "Teaser")
        }
        let fr = videos.filter { matches($0, lang: "fr") }
        let en = videos.filter { matches($0, lang: "en") }
        return Array((fr + en).prefix(6))
    }

    /// Garde les membres clés de l'équipe (réalisation, scénario, production…),
    /// sans doublon de personne.
    private func topCrew(from crew: [TMDBCrewMember]) -> [TMDBCrewMember] {
        let priorityJobs = ["Director", "Creator", "Writer", "Screenplay", "Story", "Producer", "Executive Producer", "Original Music Composer", "Composer", "Director of Photography", "Editor"]
        let filtered = crew.filter { priorityJobs.contains($0.job ?? "") }
        var seen = Set<Int>()
        var result: [TMDBCrewMember] = []
        for member in filtered where !seen.contains(member.id) {
            seen.insert(member.id)
            result.append(member)
        }
        return Array(result.prefix(10))
    }

    // ── Actions (optimistes) ──────────────────────────────────────────────

    func toggleSeen() async {
        let newValue = !seen
        applyLocalState(seen: newValue, liked: liked)
        do {
            try await api.markSeen(tmdbId: tmdbId, type: type, seen: newValue, posterPath: posterPath, runtime: movie?.runtime)
            newValue ? Haptics.success() : Haptics.impact(.light)
        } catch {
            applyLocalState(seen: !newValue, liked: liked)
            errorMessage = error.localizedDescription
            Haptics.error()
        }
    }

    func toggleLiked() async {
        let newValue = !liked
        applyLocalState(seen: seen, liked: newValue)
        do {
            try await api.markLiked(tmdbId: tmdbId, type: type, liked: newValue, posterPath: posterPath)
            Haptics.impact(newValue ? .medium : .light)
        } catch {
            applyLocalState(seen: seen, liked: !newValue)
            errorMessage = error.localizedDescription
            Haptics.error()
        }
    }

    func addToWatchlist() async {
        do {
            try await api.addToWatchlist(tmdbId: tmdbId, type: type,
                                         posterPath: posterPath, runtime: movie?.runtime)
            Haptics.success()
        } catch {
            errorMessage = error.localizedDescription
            Haptics.error()
        }
    }

    // ── Saisons / épisodes ────────────────────────────────────────────────

    func epKey(_ season: Int, _ episode: Int) -> String { "\(season)-\(episode)" }

    func isEpisodeSeen(season: Int, episode: Int) -> Bool {
        episodesSeen.contains(epKey(season, episode))
    }

    /// Nombre d'épisodes vus d'une saison, dérivé du set (sans charger les épisodes).
    func seenCount(inSeason season: Int) -> Int {
        let prefix = "\(season)-"
        return episodesSeen.filter { $0.hasPrefix(prefix) }.count
    }

    /// Saison entièrement vue, dérivé du set + episodeCount (sans charger les épisodes).
    func isSeasonFullySeen(_ season: Int, episodeCount: Int) -> Bool {
        episodeCount > 0 && seenCount(inSeason: season) >= episodeCount
    }

    /// Déplie / replie une saison, en chargeant ses épisodes au besoin.
    func toggleSeason(_ number: Int) async {
        Haptics.selection()
        if expandedSeason == number {
            expandedSeason = nil
            return
        }
        expandedSeason = number
        await loadSeasonIfNeeded(number)
    }

    private func loadSeasonIfNeeded(_ number: Int) async {
        guard seasonEpisodes[number] == nil, let showId = show?.id else { return }
        loadingSeasons.insert(number)
        if let detail = try? await tmdb.season(showId: showId, seasonNumber: number) {
            seasonEpisodes[number] = detail.episodes
        }
        loadingSeasons.remove(number)
    }

    func toggleEpisodeSeen(season: Int, episode: Int) async {
        guard let showId = show?.id else { return }
        let key = epKey(season, episode)
        let newSeen = !episodesSeen.contains(key)

        if newSeen { episodesSeen.insert(key) } else { episodesSeen.remove(key) }

        do {
            try await api.markEpisodeSeen(showTmdbId: showId, season: season, episode: episode, seen: newSeen)
            Haptics.impact(.light)
        } catch {
            if newSeen { episodesSeen.remove(key) } else { episodesSeen.insert(key) }
            errorMessage = error.localizedDescription
            Haptics.error()
        }
        await syncShowSeen()
    }

    func toggleSeasonSeen(_ season: Int, episodeCount: Int) async {
        guard let showId = show?.id else { return }
        let newSeen = !isSeasonFullySeen(season, episodeCount: episodeCount)
        // Si les épisodes ne sont pas chargés, on utilise 1...episodeCount (comme le bouton série).
        let numbers = seasonEpisodes[season]?.map(\.episodeNumber)
            ?? (episodeCount > 0 ? Array(1...episodeCount) : [])
        guard !numbers.isEmpty else { return }
        let previous = episodesSeen

        for number in numbers {
            let key = epKey(season, number)
            if newSeen { episodesSeen.insert(key) } else { episodesSeen.remove(key) }
        }

        do {
            try await api.markSeasonSeen(showTmdbId: showId, season: season, seen: newSeen, episodeNumbers: numbers)
            newSeen ? Haptics.success() : Haptics.impact(.light)
        } catch {
            episodesSeen = previous
            errorMessage = error.localizedDescription
            Haptics.error()
        }
        await syncShowSeen()
    }

    /// Recalcule l'état "vu" global de la série à partir des épisodes (vue quand toutes
    /// ses saisons réelles le sont) et le persiste si la valeur a changé.
    private func syncShowSeen() async {
        let derived = computeShowSeen()
        guard derived != seen else { return }

        applyLocalState(seen: derived, liked: liked)
        do {
            try await api.markSeen(tmdbId: tmdbId, type: type, seen: derived,
                                   posterPath: posterPath, runtime: movie?.runtime)
        } catch {
            // Optimiste : réconcilié au prochain reload.
        }
    }

    /// Vrai si toutes les saisons réelles (épisodes connus) sont vues.
    private func computeShowSeen() -> Bool {
        let real = seasons.filter { ($0.episodeCount ?? 0) > 0 }
        guard !real.isEmpty else { return false }
        return real.allSatisfy { season in
            let prefix = "\(season.seasonNumber)-"
            let seenInSeason = episodesSeen.filter { $0.hasPrefix(prefix) }.count
            return seenInSeason >= (season.episodeCount ?? 0)
        }
    }

    private func applyLocalState(seen: Bool, liked: Bool) {
        state = UserState(tmdbId: tmdbId, seen: seen, liked: liked, listIds: state?.listIds ?? [])
    }
}
