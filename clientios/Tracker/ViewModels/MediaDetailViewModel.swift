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
    /// Identifiant de la liste système « Watchlist » (chargé une fois), nécessaire
    /// pour dériver l'appartenance depuis `state.listIds` et basculer add/remove.
    private(set) var watchlistId: Int?
    /// Toutes les listes (système + perso), chargées une fois.
    private(set) var allLists: [MediaListSummary] = []
    /// Liste dont l'ajout/retrait est en cours (pour désactiver la ligne correspondante).
    private(set) var listPendingId: Int?
    private(set) var similar: [TMDBSearchResult] = []
    private(set) var cast: [TMDBCastMember] = []
    private(set) var crew: [TMDBCrewMember] = []
    private(set) var trailers: [TMDBVideo] = []
    private(set) var isLoading = false
    /// Chargement du contenu secondaire (distribution, équipe, bandes-annonces, similaires).
    private(set) var isLoadingExtras = false
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

    /// Vrai si le média figure dans la watchlist (dérivé de `state.listIds`).
    var inWatchlist: Bool {
        guard let watchlistId else { return false }
        return isInList(watchlistId)
    }

    /// Listes personnalisées (non système) proposées dans le sélecteur.
    var customLists: [MediaListSummary] { allLists.filter { !$0.isSystem } }

    /// Vrai si le média appartient à au moins une liste personnalisée (état actif du bouton).
    var isInAnyCustomList: Bool { customLists.contains { isInList($0.id) } }

    /// Vrai si le média figure dans la liste donnée (dérivé de `state.listIds`).
    func isInList(_ listId: Int) -> Bool {
        state?.listIds.contains(listId) ?? false
    }

    func load(forceRefresh: Bool = false) async {
        // Rafraîchissement forcé : on ignore le cache HTTP des requêtes de données
        // (sinon TMDB/backend resservent les mêmes réponses → "rien ne change").
        // Le contournement est ciblé par requête (cf. services) : on NE purge PAS le
        // cache global, sinon les images devraient se re-télécharger → toute la page
        // clignote (contenu effacé puis réaffiché). Le contenu déjà affiché est juste
        // remplacé en place par les nouvelles données.
        await loadDetail(forceRefresh: forceRefresh)
        await loadExtras(forceRefresh: forceRefresh)
    }

    /// Contenu principal : fiche TMDB, état utilisateur et épisodes vus.
    private func loadDetail(forceRefresh: Bool = false) async {
        isLoading = true
        errorMessage = nil
        do {
            switch type {
            case .movie: movie = try await tmdb.movie(tmdbId, forceRefresh: forceRefresh)
            case .tv: show = try await tmdb.show(tmdbId, forceRefresh: forceRefresh)
            }
            state = try await api.states(tmdbIds: [tmdbId], type: type, forceRefresh: forceRefresh).first
            // Listes (système + perso), chargées une seule fois : sert à l'état actif
            // du bouton « À voir » (watchlist) et au sélecteur de listes personnalisées.
            if allLists.isEmpty {
                allLists = (try? await api.lists()) ?? []
                watchlistId = allLists.first { $0.isSystem && $0.name == "Watchlist" }?.id
            }
            if type == .tv {
                let seen = try await api.showEpisodes(showTmdbId: tmdbId, forceRefresh: forceRefresh)
                episodesSeen = Set(seen.filter(\.seen).map { epKey($0.seasonNumber, $0.episodeNumber) })
                // Ne PAS recalculer l'état "vu" global ici : une série peut être marquée
                // vue directement (bouton « Vu ») sans qu'aucun épisode soit enregistré.
                // On fait confiance à l'état persisté (state.seen). syncShowSeen() ne doit
                // tourner qu'après un toggle d'épisode/saison.
            }
        } catch {
            if !error.isCancellation { errorMessage = error.localizedDescription }
        }
        isLoading = false
    }

    /// Contenus secondaires (similaires, distribution, bandes-annonces) : un échec
    /// ne doit ni masquer le détail, ni vider le contenu déjà affiché.
    private func loadExtras(forceRefresh: Bool = false) async {
        isLoadingExtras = true
        async let similar = tmdb.similar(tmdbId, type: type, forceRefresh: forceRefresh)
        async let credits = tmdb.credits(tmdbId, type: type, forceRefresh: forceRefresh)
        async let videos = tmdb.videos(tmdbId, type: type, forceRefresh: forceRefresh)

        if let similarResults = try? await similar {
            self.similar = similarResults
        }
        if let credits = try? await credits {
            cast = Array(credits.cast.prefix(12))
            crew = topCrew(from: credits.crew)
        }
        if let videos = try? await videos {
            trailers = filterTrailers(videos.results)
        }
        isLoadingExtras = false
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

        // Séries : marquer la série « vue » doit propager à toutes ses saisons/épisodes
        // (et inversement pour « non vue »), via l'endpoint dédié /Shows/{id}/seen.
        if type == .tv {
            await toggleShowSeen(newValue)
            return
        }

        applyLocalState(seen: newValue, liked: liked)
        do {
            try await api.markSeen(tmdbId: tmdbId, type: type, seen: newValue, posterPath: posterPath, runtime: movie?.runtime)
            newValue ? Haptics.success() : Haptics.impact(.light)
        } catch {
            applyLocalState(seen: !newValue, liked: liked)
            if !error.isCancellation { errorMessage = error.localizedDescription }
            Haptics.error()
        }
    }

    /// Marque la série entière vue / non vue et propage à toutes ses saisons/épisodes.
    private func toggleShowSeen(_ newValue: Bool) async {
        // Toutes les saisons réelles avec leurs numéros d'épisodes (1...episodeCount).
        let allSeasons: [(seasonNumber: Int, episodeNumbers: [Int])] = seasons.compactMap { season in
            let count = season.episodeCount ?? 0
            guard count > 0 else { return nil }
            return (season.seasonNumber, Array(1...count))
        }

        // Sauvegarde pour rollback.
        let previousState = state
        let previousEpisodes = episodesSeen

        // Mise à jour optimiste : état global + set d'épisodes.
        applyLocalState(seen: newValue, liked: liked)
        if newValue {
            for season in allSeasons {
                setEpisodesSeen(season: season.seasonNumber, episodes: season.episodeNumbers, seen: true)
            }
        } else {
            episodesSeen.removeAll()
        }

        do {
            try await api.markShowSeen(showTmdbId: tmdbId, seen: newValue, seasons: allSeasons)
            newValue ? Haptics.success() : Haptics.impact(.light)
        } catch {
            state = previousState
            episodesSeen = previousEpisodes
            if !error.isCancellation { errorMessage = error.localizedDescription }
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
            if !error.isCancellation { errorMessage = error.localizedDescription }
            Haptics.error()
        }
    }

    /// Ajoute / retire le média de la watchlist (mise à jour optimiste).
    func toggleWatchlist() async {
        let adding = !inWatchlist
        let previous = state
        setWatchlistMembership(adding)
        do {
            if adding {
                try await api.addToWatchlist(tmdbId: tmdbId, type: type,
                                             posterPath: posterPath, runtime: movie?.runtime)
            } else {
                try await api.removeFromWatchlist(tmdbId: tmdbId, type: type)
            }
            adding ? Haptics.success() : Haptics.impact(.light)
        } catch {
            state = previous
            if !error.isCancellation { errorMessage = error.localizedDescription }
            Haptics.error()
        }
    }

    /// Met à jour localement l'appartenance à la watchlist dans `state.listIds`.
    private func setWatchlistMembership(_ member: Bool) {
        guard let watchlistId else { return }
        setListMembership(watchlistId, member: member)
    }

    /// Ajoute / retire le média d'une liste personnalisée (mise à jour optimiste).
    func toggleList(_ listId: Int) async {
        guard listPendingId == nil else { return }
        let adding = !isInList(listId)
        let previous = state
        listPendingId = listId
        setListMembership(listId, member: adding)
        do {
            if adding {
                try await api.addItemToList(listId: listId, tmdbId: tmdbId, type: type, posterPath: posterPath)
            } else {
                try await api.removeItemFromList(listId: listId, tmdbId: tmdbId, type: type)
            }
            adding ? Haptics.success() : Haptics.impact(.light)
        } catch {
            state = previous
            if !error.isCancellation { errorMessage = error.localizedDescription }
            Haptics.error()
        }
        listPendingId = nil
    }

    /// Met à jour localement l'appartenance à une liste dans `state.listIds`.
    private func setListMembership(_ listId: Int, member: Bool) {
        guard let current = state else { return }
        var ids = current.listIds
        if member {
            if !ids.contains(listId) { ids.append(listId) }
        } else {
            ids.removeAll { $0 == listId }
        }
        state = UserState(tmdbId: current.tmdbId, seen: current.seen,
                          liked: current.liked, listIds: ids)
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
        let newSeen = !isEpisodeSeen(season: season, episode: episode)

        setEpisodesSeen(season: season, episodes: [episode], seen: newSeen)

        do {
            try await api.markEpisodeSeen(showTmdbId: showId, season: season, episode: episode, seen: newSeen)
            Haptics.impact(.light)
        } catch {
            setEpisodesSeen(season: season, episodes: [episode], seen: !newSeen)
            if !error.isCancellation { errorMessage = error.localizedDescription }
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

        setEpisodesSeen(season: season, episodes: numbers, seen: newSeen)

        do {
            try await api.markSeasonSeen(showTmdbId: showId, season: season, seen: newSeen, episodeNumbers: numbers)
            newSeen ? Haptics.success() : Haptics.impact(.light)
        } catch {
            episodesSeen = previous
            if !error.isCancellation { errorMessage = error.localizedDescription }
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
        return real.allSatisfy { isSeasonFullySeen($0.seasonNumber, episodeCount: $0.episodeCount ?? 0) }
    }

    /// Ajoute / retire d'un coup plusieurs épisodes d'une saison du set des épisodes vus.
    private func setEpisodesSeen(season: Int, episodes: [Int], seen: Bool) {
        for episode in episodes {
            let key = epKey(season, episode)
            if seen { episodesSeen.insert(key) } else { episodesSeen.remove(key) }
        }
    }

    private func applyLocalState(seen: Bool, liked: Bool) {
        state = UserState(tmdbId: tmdbId, seen: seen, liked: liked, listIds: state?.listIds ?? [])
    }
}
