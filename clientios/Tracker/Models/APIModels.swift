//
//  APIModels.swift
//  Tracker
//
//  Modèles échangés avec le backend Tracker (états utilisateur, listes, stats).
//  Correspondent aux DTO C# côté serveur.
//

import Foundation

/// État utilisateur d'un média (renvoyé par GET /Media/states).
struct UserState: Decodable, Identifiable {
    let tmdbId: Int
    let seen: Bool
    let liked: Bool
    let listIds: [Int]

    var id: Int { tmdbId }
}

/// Résumé d'une liste (système ou personnalisée).
struct MediaListSummary: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let description: String?
    let icon: String?
    let isSystem: Bool
    let createdAt: Date?
    let updatedAt: Date?

    // La prod renvoie moviesCount/showsCount ; d'anciennes versions itemsCount.
    private let moviesCount: Int?
    private let showsCount: Int?
    private let itemsCountRaw: Int?

    /// Nombre total d'éléments, quel que soit le format renvoyé par le backend.
    var itemsCount: Int {
        itemsCountRaw ?? ((moviesCount ?? 0) + (showsCount ?? 0))
    }

    enum CodingKeys: String, CodingKey {
        case id, name, description, icon, isSystem, createdAt, updatedAt
        case moviesCount, showsCount
        case itemsCountRaw = "itemsCount"
    }
}

/// Élément d'une liste, enrichi de l'état utilisateur.
struct MediaListItem: Decodable, Identifiable, Hashable {
    let tmdbId: Int
    let mediaType: String
    let posterPath: String?
    let seen: Bool
    let liked: Bool
    let addedAt: Date?

    var id: Int { tmdbId }

    var type: MediaType { mediaType == "tv" ? .tv : .movie }
}

/// Résultat paginé générique du backend.
struct PaginatedResult<T: Decodable>: Decodable {
    let items: [T]
    let page: Int
    let pageSize: Int
    let totalCount: Int
    let totalPages: Int
}

/// État "vu" d'un épisode.
struct EpisodeSeen: Decodable, Hashable {
    let seasonNumber: Int
    let episodeNumber: Int
    let seen: Bool
}

// ── Statistiques ──────────────────────────────────────────────────────────

struct Stats: Decodable {
    let moviesSeenCount: Int
    let showsSeenCount: Int
    let episodesSeenCount: Int
    let totalRuntimeMinutes: Int
    let totalRuntimeHours: Double
    let moviesSeenByYear: [StatsYearBucket]
    let moviesSeenByMonth: [StatsMonthBucket]
    let showsSeenByYear: [StatsYearBucket]
    let showsSeenByMonth: [StatsMonthBucket]
}

struct StatsYearBucket: Decodable, Identifiable, Hashable {
    let year: Int
    let count: Int
    var id: Int { year }
}

struct StatsMonthBucket: Decodable, Identifiable, Hashable {
    let year: Int
    let month: Int
    let count: Int
    var id: String { "\(year)-\(month)" }
}
