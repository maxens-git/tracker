//
//  APIService.swift
//  Tracker
//
//  Accès au backend Tracker : états utilisateur (vu / aimé / watchlist),
//  listes et statistiques.
//

import Foundation

struct APIService {
    static let shared = APIService()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(session: URLSession = .shared) {
        self.session = session

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .trackerFlexible
        self.decoder = decoder

        self.encoder = JSONEncoder()
    }

    // ── Requête générique ─────────────────────────────────────────────────

    private func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        query: [URLQueryItem] = [],
        body: Data? = nil,
        forceRefresh: Bool = false
    ) async throws -> T {
        let data = try await rawRequest(path, method: method, query: query, body: body, forceRefresh: forceRefresh)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decoding(error)
        }
    }

    /// Variante sans corps de réponse attendu (POST/PUT/DELETE).
    @discardableResult
    private func rawRequest(
        _ path: String,
        method: String = "GET",
        query: [URLQueryItem] = [],
        body: Data? = nil,
        forceRefresh: Bool = false
    ) async throws -> Data {
        var components = URLComponents(string: AppConfig.apiBaseURL + path)
        if !query.isEmpty { components?.queryItems = query }
        guard let url = components?.url else { throw NetworkError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = method
        if forceRefresh { req.cachePolicy = .reloadIgnoringLocalCacheData }
        if let body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                throw NetworkError.badStatus(code, message: Self.serverMessage(from: data))
            }
            return data
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.transport(error)
        }
    }

    /// Extrait un message d'erreur lisible du corps d'une réponse en échec.
    /// Le backend renvoie souvent une chaîne JSON ("Already in list") ou un objet { message }.
    private static func serverMessage(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        if let s = try? JSONDecoder().decode(String.self, from: data),
           !s.isEmpty { return s }
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = obj["message"] as? String { return message }
        if let s = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !s.isEmpty, !s.hasPrefix("<") { return s }
        return nil
    }

    // ── États utilisateur ─────────────────────────────────────────────────

    func states(tmdbIds: [Int], type: MediaType, forceRefresh: Bool = false) async throws -> [UserState] {
        guard !tmdbIds.isEmpty else { return [] }
        return try await request("/Media/states", query: [
            URLQueryItem(name: "tmdbIds", value: tmdbIds.map(String.init).joined(separator: ",")),
            URLQueryItem(name: "type", value: type.rawValue),
        ], forceRefresh: forceRefresh)
    }

    /// Ensemble des médias déjà « vus » parmi les résultats donnés.
    /// Clé : "movie-123" / "tv-123" (évite les collisions d'id entre films et séries).
    /// Les erreurs réseau sont ignorées : un badge manquant ne doit pas casser l'écran.
    func seenStateKeys(for results: [TMDBSearchResult]) async -> Set<String> {
        let movieIds = results.filter { $0.mediaType == .movie }.map(\.id)
        let showIds = results.filter { $0.mediaType == .tv }.map(\.id)

        async let movieStates = states(tmdbIds: movieIds, type: .movie)
        async let showStates = states(tmdbIds: showIds, type: .tv)

        let movies = (try? await movieStates) ?? []
        let shows = (try? await showStates) ?? []

        var keys: Set<String> = []
        for s in movies where s.seen { keys.insert("movie-\(s.tmdbId)") }
        for s in shows where s.seen { keys.insert("tv-\(s.tmdbId)") }
        return keys
    }

    func markSeen(tmdbId: Int, type: MediaType, seen: Bool, posterPath: String? = nil, runtime: Int? = nil, genres: [TMDBGenre] = []) async throws {
        var payload: [String: AnyEncodable] = ["seen": AnyEncodable(seen)]
        if let posterPath { payload["posterPath"] = AnyEncodable(posterPath) }
        if let runtime { payload["runtime"] = AnyEncodable(runtime) }
        if !genres.isEmpty { payload["genres"] = AnyEncodable(genres) }
        let body = try encoder.encode(payload)
        try await rawRequest("/Media/\(tmdbId)/seen", method: "POST",
                             query: [URLQueryItem(name: "type", value: type.rawValue)], body: body)
    }

    func markLiked(tmdbId: Int, type: MediaType, liked: Bool, posterPath: String? = nil) async throws {
        let body = try encoder.encode(liked)
        var query = [URLQueryItem(name: "type", value: type.rawValue)]
        if let posterPath { query.append(URLQueryItem(name: "posterPath", value: posterPath)) }
        try await rawRequest("/Media/\(tmdbId)/liked", method: "POST",
                             query: query, body: body)
    }

    func addToWatchlist(tmdbId: Int, type: MediaType, posterPath: String?, runtime: Int? = nil, genres: [TMDBGenre] = []) async throws {
        var payload: [String: AnyEncodable] = [:]
        if let posterPath { payload["posterPath"] = AnyEncodable(posterPath) }
        if let runtime { payload["runtime"] = AnyEncodable(runtime) }
        if !genres.isEmpty { payload["genres"] = AnyEncodable(genres) }
        let body = try encoder.encode(payload)
        try await rawRequest("/Media/\(tmdbId)/watchlist", method: "POST",
                             query: [URLQueryItem(name: "type", value: type.rawValue)], body: body)
    }

    func removeFromWatchlist(tmdbId: Int, type: MediaType) async throws {
        try await rawRequest("/Media/\(tmdbId)/watchlist", method: "DELETE",
                             query: [URLQueryItem(name: "type", value: type.rawValue)])
    }

    // ── Épisodes ──────────────────────────────────────────────────────────

    func showEpisodes(showTmdbId: Int, forceRefresh: Bool = false) async throws -> [EpisodeSeen] {
        try await request("/Shows/\(showTmdbId)/episodes", forceRefresh: forceRefresh)
    }

    /// Séries « en cours » : au moins un épisode vu, série non terminée.
    func inProgressShows(forceRefresh: Bool = false) async throws -> [InProgressShow] {
        try await request("/Shows/in-progress", forceRefresh: forceRefresh)
    }

    func markEpisodeSeen(showTmdbId: Int, season: Int, episode: Int, seen: Bool) async throws {
        let body = try encoder.encode(seen)
        try await rawRequest("/Shows/\(showTmdbId)/seasons/\(season)/episodes/\(episode)/seen",
                             method: "POST", body: body)
    }

    func markSeasonSeen(showTmdbId: Int, season: Int, seen: Bool, episodeNumbers: [Int]) async throws {
        let payload: [String: AnyEncodable] = [
            "seen": AnyEncodable(seen),
            "episodeNumbers": AnyEncodable(episodeNumbers),
        ]
        let body = try encoder.encode(payload)
        try await rawRequest("/Shows/\(showTmdbId)/seasons/\(season)/seen", method: "POST", body: body)
    }

    /// Marque la série entière vue / non vue, en propageant à toutes les saisons/épisodes fournis.
    func markShowSeen(showTmdbId: Int, seen: Bool, seasons: [(seasonNumber: Int, episodeNumbers: [Int])], posterPath: String? = nil, genres: [TMDBGenre] = []) async throws {
        let payload: [String: AnyEncodable] = [
            "seen": AnyEncodable(seen),
            "seasons": AnyEncodable(seasons.map { season in
                ["seasonNumber": AnyEncodable(season.seasonNumber),
                 "episodeNumbers": AnyEncodable(season.episodeNumbers)]
            }),
        ]
        var enrichedPayload = payload
        if let posterPath { enrichedPayload["posterPath"] = AnyEncodable(posterPath) }
        if !genres.isEmpty { enrichedPayload["genres"] = AnyEncodable(genres) }
        let body = try encoder.encode(enrichedPayload)
        try await rawRequest("/Shows/\(showTmdbId)/seen", method: "POST", body: body)
    }

    // ── Listes ────────────────────────────────────────────────────────────

    func lists() async throws -> [MediaListSummary] {
        try await request("/MediaLists")
    }

    /// `listId` accepte un identifiant numérique ou un alias système ("seen", "liked", "watchlist").
    func listItems(listId: String, page: Int = 1, type: String = "all") async throws -> PaginatedResult<MediaListItem> {
        try await request("/MediaLists/\(listId)/items", query: [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "type", value: type),
        ])
    }

    func createList(name: String, description: String? = nil, icon: String? = nil) async throws -> MediaListSummary {
        var payload: [String: AnyEncodable] = ["name": AnyEncodable(name)]
        if let description { payload["description"] = AnyEncodable(description) }
        if let icon { payload["icon"] = AnyEncodable(icon) }
        let body = try encoder.encode(payload)
        return try await request("/MediaLists", method: "POST", body: body)
    }

    /// Met à jour une liste personnalisée (le backend refuse les listes système).
    /// Les champs vides sont envoyés tels quels (chaîne vide = efface description/icône).
    func updateList(id: Int, name: String, description: String, icon: String) async throws {
        let payload: [String: AnyEncodable] = [
            "name": AnyEncodable(name),
            "description": AnyEncodable(description),
            "icon": AnyEncodable(icon),
        ]
        let body = try encoder.encode(payload)
        try await rawRequest("/MediaLists/\(id)", method: "PUT", body: body)
    }

    func deleteList(id: Int) async throws {
        try await rawRequest("/MediaLists/\(id)", method: "DELETE")
    }

    func addItemToList(listId: Int, tmdbId: Int, type: MediaType, posterPath: String?, genres: [TMDBGenre] = []) async throws {
        var payload: [String: AnyEncodable] = [
            "tmdbId": AnyEncodable(tmdbId),
            "mediaType": AnyEncodable(type.rawValue),
        ]
        if let posterPath { payload["posterPath"] = AnyEncodable(posterPath) }
        if !genres.isEmpty { payload["genres"] = AnyEncodable(genres) }
        let body = try encoder.encode(payload)
        try await rawRequest("/MediaLists/\(listId)/items", method: "POST", body: body)
    }

    func removeItemFromList(listId: Int, tmdbId: Int, type: MediaType) async throws {
        try await rawRequest("/MediaLists/\(listId)/items/\(tmdbId)", method: "DELETE",
                             query: [URLQueryItem(name: "type", value: type.rawValue)])
    }

    // ── Stats ─────────────────────────────────────────────────────────────

    func stats() async throws -> Stats {
        try await request("/Stats")
    }

    func genresByList() async throws -> [StatsListGenres] {
        try await request("/Stats/genres-by-list")
    }

    // ── Activité ────────────────────────────────────────────────────────────

    func activity(page: Int = 1) async throws -> PaginatedResult<Activity> {
        try await request("/Activity", query: [URLQueryItem(name: "page", value: String(page))])
    }

    // ── Logs système ──────────────────────────────────────────────────────

    /// Journal système paginé. `level` = "all" (aucun filtre) ou "Information"/"Warning"/"Error"/"Critical".
    func logs(page: Int = 1, level: String = "all", search: String = "") async throws -> PaginatedResult<SystemLog> {
        var query = [URLQueryItem(name: "page", value: String(page))]
        if level != "all" { query.append(URLQueryItem(name: "level", value: level)) }
        let trimmed = search.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { query.append(URLQueryItem(name: "search", value: trimmed)) }
        return try await request("/Logs", query: query)
    }

    func clearLogs() async throws {
        try await rawRequest("/Logs", method: "DELETE")
    }

    // ── Réglages & sorties ────────────────────────────────────────────────

    func settings(forceRefresh: Bool = false) async throws -> AppSettingsDTO {
        try await request("/Settings", forceRefresh: forceRefresh)
    }

    func updateSettings(_ settings: AppSettingsDTO) async throws -> AppSettingsDTO {
        let body = try encoder.encode(settings)
        return try await request("/Settings", method: "PUT", body: body)
    }

    func trackedMedia(forceRefresh: Bool = false) async throws -> [TrackedMedia] {
        try await request("/TrackedMedia", forceRefresh: forceRefresh)
    }

    func trackedMediaState(tmdbId: Int, type: MediaType, forceRefresh: Bool = false) async throws -> TrackedMediaState {
        try await request("/TrackedMedia/state", query: [
            URLQueryItem(name: "tmdbId", value: String(tmdbId)),
            URLQueryItem(name: "type", value: type.rawValue),
        ], forceRefresh: forceRefresh)
    }

    /// Variante tolérante : renvoie `false` plutôt que de propager une erreur réseau,
    /// pour l'état initial du bouton « Sortie » qui ne doit pas bloquer le chargement.
    func isReleaseTracked(tmdbId: Int, type: MediaType, forceRefresh: Bool = false) async -> Bool {
        (try? await trackedMediaState(tmdbId: tmdbId, type: type, forceRefresh: forceRefresh))?.tracked ?? false
    }

    func addTrackedMedia(tmdbId: Int, type: MediaType, title: String, posterPath: String?) async throws -> TrackedMedia {
        var payload: [String: AnyEncodable] = [
            "tmdbId": AnyEncodable(tmdbId),
            "mediaType": AnyEncodable(type.rawValue),
            "title": AnyEncodable(title),
        ]
        if let posterPath { payload["posterPath"] = AnyEncodable(posterPath) }
        let body = try encoder.encode(payload)
        return try await request("/TrackedMedia", method: "POST", body: body)
    }

    func removeTrackedMedia(tmdbId: Int, type: MediaType) async throws {
        try await rawRequest("/TrackedMedia/\(tmdbId)", method: "DELETE",
                             query: [URLQueryItem(name: "type", value: type.rawValue)])
    }

    /// URL d'abonnement au calendrier des sorties (webcal + https), prête à ouvrir.
    func calendarInfo(forceRefresh: Bool = false) async throws -> CalendarInfo {
        try await request("/calendar/info", forceRefresh: forceRefresh)
    }

    // ── Torrents & débridage ──────────────────────────────────────────────

    func torrentIndexers() async throws -> [Indexer] {
        try await request("/torrents/indexers")
    }

    func torrentCategories() async throws -> [TorrentCategory] {
        try await request("/torrents/categories")
    }

    /// Recherche Prowlarr. `indexerIds` vide = tous ; `categoryId` nil = toutes.
    func searchTorrents(query: String, indexerIds: [Int], categoryId: Int?) async throws -> [TorrentResult] {
        var items = [URLQueryItem(name: "query", value: query)]
        // Répété (indexerIds=1&indexerIds=2) pour le binding `int[]` d'ASP.NET.
        items += indexerIds.map { URLQueryItem(name: "indexerIds", value: String($0)) }
        if let categoryId { items.append(URLQueryItem(name: "categoryId", value: String(categoryId))) }
        return try await request("/torrents/search", query: items)
    }

    /// Débride un magnet : renvoie la liste des fichiers (liens encore verrouillés).
    func debridMagnet(_ magnet: String) async throws -> DebridResult {
        let body = try encoder.encode(["magnet": magnet])
        return try await request("/torrents/debrid", method: "POST", body: body)
    }

    /// Résout un lien AllDebrid verrouillé en lien de téléchargement direct.
    func unlockLink(_ link: String) async throws -> UnlockResult {
        let body = try encoder.encode(["link": link])
        return try await request("/torrents/unlock", method: "POST", body: body)
    }

    // ── Marque-pages torrents ──────────────────────────────────────────────

    func torrentBookmarks() async throws -> [TorrentBookmark] {
        try await request("/torrent-bookmarks")
    }

    /// Met un torrent de côté. Idempotent côté backend (même infohash → même entrée).
    @discardableResult
    func addTorrentBookmark(_ torrent: TorrentResult) async throws -> TorrentBookmark {
        var payload: [String: AnyEncodable] = [
            "title": AnyEncodable(torrent.title),
            "size": AnyEncodable(torrent.size),
            "seeders": AnyEncodable(torrent.seeders),
            "leechers": AnyEncodable(torrent.leechers),
            "indexer": AnyEncodable(torrent.indexer),
            "magnetUrl": AnyEncodable(torrent.magnetUrl),
        ]
        if let category = torrent.category { payload["category"] = AnyEncodable(category) }
        if let publishDate = torrent.publishDate { payload["publishDate"] = AnyEncodable(publishDate) }
        let body = try encoder.encode(payload)
        return try await request("/torrent-bookmarks", method: "POST", body: body)
    }

    func removeTorrentBookmark(id: Int) async throws {
        try await rawRequest("/torrent-bookmarks/\(id)", method: "DELETE")
    }

    // ── Séances de cinéma (Allociné) ──────────────────────────────────────

    /// Programme de plusieurs cinémas pour une date (YYYY-MM-DD, défaut aujourd'hui côté serveur).
    /// Une salle injoignable est simplement absente du résultat.
    func multiShowtimes(codes: [String], date: String?) async throws -> [TheaterShowtimes] {
        var query = [URLQueryItem(name: "theaters", value: codes.joined(separator: ","))]
        if let date { query.append(URLQueryItem(name: "date", value: date)) }
        return try await request("/showtimes/multi", query: query)
    }

    // ── Cinémas favoris ────────────────────────────────────────────────────

    func favoriteTheaters() async throws -> [FavoriteTheater] {
        try await request("/favorite-theaters")
    }

    @discardableResult
    func addFavoriteTheater(code: String) async throws -> FavoriteTheater {
        let payload: [String: AnyEncodable] = ["code": AnyEncodable(code)]
        let body = try encoder.encode(payload)
        return try await request("/favorite-theaters", method: "POST", body: body)
    }

    func removeFavoriteTheater(id: Int) async throws {
        try await rawRequest("/favorite-theaters/\(id)", method: "DELETE")
    }

    func setFavoriteTheaterActive(id: Int, isActive: Bool) async throws {
        let payload: [String: AnyEncodable] = ["isActive": AnyEncodable(isActive)]
        let body = try encoder.encode(payload)
        try await rawRequest("/favorite-theaters/\(id)/active", method: "PUT", body: body)
    }
}

// MARK: - Helpers d'encodage JSON hétérogène

/// Wrapper permettant d'encoder des dictionnaires aux valeurs hétérogènes.
struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void
    init<T: Encodable>(_ value: T) { encodeFunc = value.encode }
    func encode(to encoder: Encoder) throws { try encodeFunc(encoder) }
}

// MARK: - Décodage tolérant des dates

extension JSONDecoder.DateDecodingStrategy {
    /// ASP.NET peut sérialiser les DateTime de plusieurs façons :
    /// avec ou sans fuseau ("...247331" vs "...Z"), avec un nombre variable de
    /// décimales. On essaie plusieurs formats et, en dernier recours, on ne fait
    /// jamais échouer tout le décodage pour une date (champ secondaire).
    static let trackerFlexible = custom { decoder in
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        return TrackerDateParser.parse(string) ?? Date(timeIntervalSince1970: 0)
    }
}

enum TrackerDateParser {
    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Formats ASP.NET sans fuseau (interprétés comme UTC).
    private static let formatters: [DateFormatter] = {
        ["yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
         "yyyy-MM-dd'T'HH:mm:ss.SSS",
         "yyyy-MM-dd'T'HH:mm:ss"].map { pattern in
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone(identifier: "UTC")
            f.dateFormat = pattern
            return f
        }
    }()

    static func parse(_ string: String) -> Date? {
        if let d = isoFractional.date(from: string) { return d }
        if let d = isoPlain.date(from: string) { return d }
        for f in formatters {
            if let d = f.date(from: string) { return d }
        }
        return nil
    }
}
