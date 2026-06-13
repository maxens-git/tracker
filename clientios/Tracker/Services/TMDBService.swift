//
//  TMDBService.swift
//  Tracker
//
//  Accès direct à l'API TMDB (métadonnées des films / séries).
//

import Foundation

/// Erreurs réseau génériques de l'app.
enum NetworkError: LocalizedError {
    case invalidURL
    case badStatus(Int, message: String? = nil)
    case decoding(Error)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "URL invalide."
        case .badStatus(let code, let message): return message ?? "Réponse serveur invalide (\(code))."
        case .decoding: return "Impossible de lire la réponse du serveur."
        case .transport(let error): return error.localizedDescription
        }
    }
}

extension Error {
    /// Vrai si l'erreur n'est qu'une annulation de tâche (requête remplacée, vue quittée).
    /// À ignorer côté UI plutôt que d'afficher un message « cancelled » trompeur.
    var isCancellation: Bool {
        if self is CancellationError { return true }
        if let urlError = self as? URLError, urlError.code == .cancelled { return true }
        if let netError = self as? NetworkError,
           case .transport(let underlying) = netError,
           (underlying as? URLError)?.code == .cancelled { return true }
        return false
    }
}

struct TMDBService {
    static let shared = TMDBService()

    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
    }

    // ── Construction d'URL ────────────────────────────────────────────────

    private func makeURL(_ path: String, query: [String: String] = [:]) -> URL? {
        var components = URLComponents(string: AppConfig.tmdbBaseURL + path)
        var items = [
            URLQueryItem(name: "api_key", value: AppConfig.tmdbApiKey),
            URLQueryItem(name: "language", value: AppConfig.tmdbLanguage),
        ]
        items += query.map { URLQueryItem(name: $0.key, value: $0.value) }
        components?.queryItems = items
        return components?.url
    }

    private func get<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        guard let url = makeURL(path, query: query) else { throw NetworkError.invalidURL }
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw NetworkError.badStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
            }
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw NetworkError.decoding(error)
            }
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.transport(error)
        }
    }

    // ── Endpoints ─────────────────────────────────────────────────────────

    /// Tendances de la semaine (films + séries).
    func trendingWeek() async throws -> [TMDBSearchResult] {
        let response: TMDBPagedResponse = try await get("/trending/all/week")
        return response.results
    }

    func popularMovies(page: Int = 1) async throws -> TMDBPagedResponse {
        try await get("/movie/popular", query: ["page": String(page)])
    }

    func popularShows(page: Int = 1) async throws -> TMDBPagedResponse {
        try await get("/tv/popular", query: ["page": String(page)])
    }

    /// Recherche multi (films, séries, personnes — filtrées en amont).
    func searchMulti(_ query: String, page: Int = 1) async throws -> TMDBPagedResponse {
        try await get("/search/multi", query: ["query": query, "page": String(page)])
    }

    /// Liste des genres (films + séries fusionnés, doublons retirés par id).
    /// Sert à proposer des filtres lisibles à partir des `genre_ids` des résultats.
    func allGenres() async throws -> [TMDBGenre] {
        async let movie: TMDBGenreList = get("/genre/movie/list")
        async let tv: TMDBGenreList = get("/genre/tv/list")
        let combined = try await movie.genres + tv.genres
        var seen = Set<Int>()
        return combined
            .filter { seen.insert($0.id).inserted }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func movie(_ id: Int) async throws -> TMDBMovie {
        try await get("/movie/\(id)")
    }

    func show(_ id: Int) async throws -> TMDBShow {
        try await get("/tv/\(id)")
    }

    /// Détail d'une saison (avec la liste des épisodes).
    func season(showId: Int, seasonNumber: Int) async throws -> TMDBSeasonDetail {
        try await get("/tv/\(showId)/season/\(seasonNumber)")
    }

    /// Médias similaires (même type que le média consulté).
    func similar(_ id: Int, type: MediaType) async throws -> [TMDBSearchResult] {
        let path = type == .movie ? "/movie/\(id)/similar" : "/tv/\(id)/similar"
        let response: TMDBPagedResponse = try await get(path)
        return response.results
    }

    /// Distribution + équipe.
    func credits(_ id: Int, type: MediaType) async throws -> TMDBCredits {
        let path = type == .movie ? "/movie/\(id)/credits" : "/tv/\(id)/credits"
        return try await get(path)
    }

    /// Bandes-annonces et autres vidéos.
    func videos(_ id: Int, type: MediaType) async throws -> TMDBVideos {
        let path = type == .movie ? "/movie/\(id)/videos" : "/tv/\(id)/videos"
        return try await get(path)
    }

    /// Détail d'une personne (acteur / membre d'équipe).
    func person(_ id: Int) async throws -> TMDBPerson {
        try await get("/person/\(id)")
    }

    /// Filmographie combinée (films + séries) d'une personne.
    func personCombinedCredits(_ id: Int) async throws -> TMDBCombinedCredits {
        try await get("/person/\(id)/combined_credits")
    }

    // ── Helpers image ─────────────────────────────────────────────────────

    /// URL d'une affiche TMDB pour une taille donnée (ex. "w342", "w500", "original").
    static func posterURL(_ path: String?, size: String = "w342") -> URL? {
        guard let path, !path.isEmpty else { return nil }
        return URL(string: "\(AppConfig.tmdbImageBaseURL)/\(size)\(path)")
    }

    static func backdropURL(_ path: String?, size: String = "w780") -> URL? {
        guard let path, !path.isEmpty else { return nil }
        return URL(string: "\(AppConfig.tmdbImageBaseURL)/\(size)\(path)")
    }

    /// Photo de profil d'une personne (cast / crew).
    static func profileURL(_ path: String?, size: String = "w185") -> URL? {
        guard let path, !path.isEmpty else { return nil }
        return URL(string: "\(AppConfig.tmdbImageBaseURL)/\(size)\(path)")
    }

    /// Vignette YouTube d'une bande-annonce.
    static func youtubeThumbnail(_ key: String) -> URL? {
        URL(string: "https://img.youtube.com/vi/\(key)/mqdefault.jpg")
    }

    /// Lien de visionnage YouTube.
    static func youtubeWatch(_ key: String) -> URL? {
        URL(string: "https://www.youtube.com/watch?v=\(key)")
    }
}
