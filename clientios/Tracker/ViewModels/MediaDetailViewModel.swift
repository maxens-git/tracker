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
        let priorityJobs = ["Director", "Creator", "Writer", "Screenplay", "Producer", "Executive Producer", "Composer", "Original Music Composer"]
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
            try await api.markSeen(tmdbId: tmdbId, type: type, seen: newValue, runtime: movie?.runtime)
        } catch {
            applyLocalState(seen: !newValue, liked: liked)
            errorMessage = error.localizedDescription
        }
    }

    func toggleLiked() async {
        let newValue = !liked
        applyLocalState(seen: seen, liked: newValue)
        do {
            try await api.markLiked(tmdbId: tmdbId, type: type, liked: newValue)
        } catch {
            applyLocalState(seen: seen, liked: !newValue)
            errorMessage = error.localizedDescription
        }
    }

    func addToWatchlist() async {
        do {
            try await api.addToWatchlist(tmdbId: tmdbId, type: type,
                                         posterPath: posterPath, runtime: movie?.runtime)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyLocalState(seen: Bool, liked: Bool) {
        state = UserState(tmdbId: tmdbId, seen: seen, liked: liked, listIds: state?.listIds ?? [])
    }
}
