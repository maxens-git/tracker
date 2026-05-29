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
        decoder.dateDecodingStrategy = .iso8601withFractionalSeconds
        self.decoder = decoder

        self.encoder = JSONEncoder()
    }

    // ── Requête générique ─────────────────────────────────────────────────

    private func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        query: [URLQueryItem] = [],
        body: Data? = nil
    ) async throws -> T {
        let data = try await rawRequest(path, method: method, query: query, body: body)
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
        body: Data? = nil
    ) async throws -> Data {
        var components = URLComponents(string: AppConfig.apiBaseURL + path)
        if !query.isEmpty { components?.queryItems = query }
        guard let url = components?.url else { throw NetworkError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = method
        if let body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw NetworkError.badStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
            }
            return data
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.transport(error)
        }
    }

    // ── États utilisateur ─────────────────────────────────────────────────

    func states(tmdbIds: [Int], type: MediaType) async throws -> [UserState] {
        guard !tmdbIds.isEmpty else { return [] }
        return try await request("/Media/states", query: [
            URLQueryItem(name: "tmdbIds", value: tmdbIds.map(String.init).joined(separator: ",")),
            URLQueryItem(name: "type", value: type.rawValue),
        ])
    }

    func markSeen(tmdbId: Int, type: MediaType, seen: Bool, runtime: Int? = nil) async throws {
        var payload: [String: AnyEncodable] = ["seen": AnyEncodable(seen)]
        if let runtime { payload["runtime"] = AnyEncodable(runtime) }
        let body = try encoder.encode(payload)
        try await rawRequest("/Media/\(tmdbId)/seen", method: "POST",
                             query: [URLQueryItem(name: "type", value: type.rawValue)], body: body)
    }

    func markLiked(tmdbId: Int, type: MediaType, liked: Bool) async throws {
        let body = try encoder.encode(liked)
        try await rawRequest("/Media/\(tmdbId)/liked", method: "POST",
                             query: [URLQueryItem(name: "type", value: type.rawValue)], body: body)
    }

    func addToWatchlist(tmdbId: Int, type: MediaType, posterPath: String?, runtime: Int? = nil) async throws {
        var payload: [String: AnyEncodable] = [:]
        if let posterPath { payload["posterPath"] = AnyEncodable(posterPath) }
        if let runtime { payload["runtime"] = AnyEncodable(runtime) }
        let body = try encoder.encode(payload)
        try await rawRequest("/Media/\(tmdbId)/watchlist", method: "POST",
                             query: [URLQueryItem(name: "type", value: type.rawValue)], body: body)
    }

    func removeFromWatchlist(tmdbId: Int, type: MediaType) async throws {
        try await rawRequest("/Media/\(tmdbId)/watchlist", method: "DELETE",
                             query: [URLQueryItem(name: "type", value: type.rawValue)])
    }

    // ── Épisodes ──────────────────────────────────────────────────────────

    func showEpisodes(showTmdbId: Int) async throws -> [EpisodeSeen] {
        try await request("/Shows/\(showTmdbId)/episodes")
    }

    func markEpisodeSeen(showTmdbId: Int, season: Int, episode: Int, seen: Bool) async throws {
        let body = try encoder.encode(seen)
        try await rawRequest("/Shows/\(showTmdbId)/seasons/\(season)/episodes/\(episode)/seen",
                             method: "POST", body: body)
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

    func deleteList(id: Int) async throws {
        try await rawRequest("/MediaLists/\(id)", method: "DELETE")
    }

    func addItemToList(listId: Int, tmdbId: Int, type: MediaType, posterPath: String?) async throws {
        var payload: [String: AnyEncodable] = [
            "tmdbId": AnyEncodable(tmdbId),
            "mediaType": AnyEncodable(type.rawValue),
        ]
        if let posterPath { payload["posterPath"] = AnyEncodable(posterPath) }
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
}

// MARK: - Helpers d'encodage JSON hétérogène

/// Wrapper permettant d'encoder des dictionnaires aux valeurs hétérogènes.
struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void
    init<T: Encodable>(_ value: T) { encodeFunc = value.encode }
    func encode(to encoder: Encoder) throws { try encodeFunc(encoder) }
}

// MARK: - Décodage des dates ISO8601 avec fractions de seconde

extension JSONDecoder.DateDecodingStrategy {
    /// ASP.NET sérialise les DateTime UTC avec des fractions de seconde
    /// (ex. "2026-05-29T18:25:00.1234567Z"), que l'ISO8601 standard rejette.
    static let iso8601withFractionalSeconds = custom { decoder in
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        if let date = ISO8601DateFormatter.fractional.date(from: string)
            ?? ISO8601DateFormatter.plain.date(from: string) {
            return date
        }
        throw DecodingError.dataCorruptedError(
            in: container, debugDescription: "Date invalide: \(string)")
    }
}

private extension ISO8601DateFormatter {
    static let fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}
