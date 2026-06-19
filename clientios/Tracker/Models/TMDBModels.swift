//
//  TMDBModels.swift
//  Tracker
//
//  Modèles décodés depuis l'API TMDB. Volontairement minimaux : on ne
//  décode que les champs réellement utilisés par l'app.
//

import Foundation

/// Résultat unifié d'une recherche / liste TMDB (films, séries).
struct TMDBSearchResult: Decodable, Identifiable, Hashable {
    let id: Int
    let title: String?          // films
    let name: String?           // séries
    let posterPath: String?
    let backdropPath: String?
    let overview: String?
    let voteAverage: Double?
    let popularity: Double?
    let releaseDate: String?    // films
    let firstAirDate: String?   // séries
    /// Présent dans /search/multi ; absent des endpoints typés (movie/tv).
    let mediaTypeRaw: String?
    /// Identifiants de genres TMDB (présents dans les listes/recherches, pas le détail).
    let genreIds: [Int]?

    enum CodingKeys: String, CodingKey {
        case id, title, name, overview, popularity
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case voteAverage = "vote_average"
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case mediaTypeRaw = "media_type"
        case genreIds = "genre_ids"
    }

    /// Titre affichable quel que soit le type.
    var displayTitle: String { title ?? name ?? "Sans titre" }

    /// Date affichable (année).
    var year: String? {
        let date = releaseDate ?? firstAirDate
        guard let date, date.count >= 4 else { return nil }
        return String(date.prefix(4))
    }

    /// Type déduit : à partir de `media_type` si présent, sinon de la forme
    /// des champs (les films ont `title`, les séries `name`).
    var mediaType: MediaType {
        if let raw = mediaTypeRaw { return raw == "tv" ? .tv : .movie }
        return title != nil ? .movie : .tv
    }
}

/// Réponse paginée standard de TMDB.
struct TMDBPagedResponse: Decodable {
    let page: Int
    let results: [TMDBSearchResult]
    let totalPages: Int
    let totalResults: Int

    enum CodingKeys: String, CodingKey {
        case page, results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }
}

/// Détail d'un film.
struct TMDBMovie: Decodable, Identifiable {
    let id: Int
    let title: String
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let runtime: Int?
    let voteAverage: Double?
    let genres: [TMDBGenre]?

    enum CodingKeys: String, CodingKey {
        case id, title, overview, runtime, genres
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case voteAverage = "vote_average"
    }
}

/// Détail d'une série.
struct TMDBShow: Decodable, Identifiable {
    let id: Int
    let name: String
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let firstAirDate: String?
    let numberOfSeasons: Int?
    let numberOfEpisodes: Int?
    let voteAverage: Double?
    let genres: [TMDBGenre]?
    let seasons: [TMDBSeasonSummary]?

    enum CodingKeys: String, CodingKey {
        case id, name, overview, genres, seasons
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case firstAirDate = "first_air_date"
        case numberOfSeasons = "number_of_seasons"
        case numberOfEpisodes = "number_of_episodes"
        case voteAverage = "vote_average"
    }
}

struct TMDBSeasonSummary: Decodable, Identifiable, Hashable {
    let id: Int
    let seasonNumber: Int
    let name: String
    let episodeCount: Int?
    let airDate: String?
    let posterPath: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case seasonNumber = "season_number"
        case episodeCount = "episode_count"
        case airDate = "air_date"
        case posterPath = "poster_path"
    }
}

struct TMDBGenre: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
}

/// Réponse de /genre/{movie,tv}/list.
struct TMDBGenreList: Decodable {
    let genres: [TMDBGenre]
}

/// Détail d'une saison avec ses épisodes (GET /tv/{id}/season/{n}).
struct TMDBSeasonDetail: Decodable {
    let id: Int
    let seasonNumber: Int
    let name: String
    let episodes: [TMDBEpisode]

    enum CodingKeys: String, CodingKey {
        case id, name, episodes
        case seasonNumber = "season_number"
    }
}

struct TMDBEpisode: Decodable, Identifiable, Hashable {
    let id: Int
    let episodeNumber: Int
    let seasonNumber: Int
    let name: String
    let overview: String?
    let runtime: Int?
    let airDate: String?
    let stillPath: String?

    enum CodingKeys: String, CodingKey {
        case id, name, overview, runtime
        case episodeNumber = "episode_number"
        case seasonNumber = "season_number"
        case airDate = "air_date"
        case stillPath = "still_path"
    }
}

// ── Crédits (distribution / équipe) ─────────────────────────────────────────

struct TMDBCredits: Decodable {
    let cast: [TMDBCastMember]
    let crew: [TMDBCrewMember]
}

struct TMDBCastMember: Decodable, Identifiable, Hashable {
    /// Identifiant de crédit (unique même si une personne a plusieurs rôles).
    let creditId: String
    let id: Int
    let name: String
    let character: String?
    let profilePath: String?

    var stableId: String { creditId }

    enum CodingKeys: String, CodingKey {
        case id, name, character
        case creditId = "credit_id"
        case profilePath = "profile_path"
    }
}

struct TMDBCrewMember: Decodable, Identifiable, Hashable {
    let creditId: String
    let id: Int
    let name: String
    let job: String?
    let department: String?
    let profilePath: String?

    var stableId: String { creditId }

    /// Métier traduit en français (TMDB renvoie toujours les `job` en anglais).
    var localizedJob: String? {
        guard let job, !job.isEmpty else { return nil }
        return CrewJob.french[job] ?? job
    }

    enum CodingKeys: String, CodingKey {
        case id, name, job, department
        case creditId = "credit_id"
        case profilePath = "profile_path"
    }
}

/// Traduction française des métiers d'équipe TMDB.
enum CrewJob {
    static let french: [String: String] = [
        "Director": "Réalisateur",
        "Creator": "Créateur",
        "Writer": "Scénariste",
        "Screenplay": "Scénario",
        "Story": "Histoire",
        "Novel": "Roman",
        "Producer": "Producteur",
        "Executive Producer": "Producteur exécutif",
        "Original Music Composer": "Compositeur",
        "Composer": "Compositeur",
        "Director of Photography": "Directeur de la photographie",
        "Editor": "Monteur",
    ]
}

// ── Personne (détail + filmographie) ────────────────────────────────────────

/// Détail d'une personne (GET /person/{id}).
struct TMDBPerson: Decodable, Identifiable {
    let id: Int
    let name: String
    let biography: String?
    let birthday: String?
    let deathday: String?
    let placeOfBirth: String?
    let profilePath: String?
    let knownForDepartment: String?

    enum CodingKeys: String, CodingKey {
        case id, name, biography, birthday, deathday
        case placeOfBirth = "place_of_birth"
        case profilePath = "profile_path"
        case knownForDepartment = "known_for_department"
    }
}

/// Crédit (film ou série) d'une filmographie (GET /person/{id}/combined_credits).
struct TMDBPersonCredit: Decodable, Identifiable, Hashable {
    let id: Int
    let mediaTypeRaw: String?
    let title: String?       // films
    let name: String?        // séries
    let posterPath: String?
    let releaseDate: String?
    let firstAirDate: String?
    let voteAverage: Double?
    let character: String?
    let job: String?

    enum CodingKeys: String, CodingKey {
        case id, title, name, character, job
        case mediaTypeRaw = "media_type"
        case posterPath = "poster_path"
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case voteAverage = "vote_average"
    }
}

/// Filmographie combinée (films + séries) d'une personne.
struct TMDBCombinedCredits: Decodable {
    let cast: [TMDBPersonCredit]
    let crew: [TMDBPersonCredit]
}

// ── Vidéos (bandes-annonces) ────────────────────────────────────────────────

struct TMDBVideos: Decodable {
    let results: [TMDBVideo]
}

struct TMDBVideo: Decodable, Identifiable, Hashable {
    let id: String
    let key: String
    let name: String
    let site: String
    let type: String
    let language: String

    enum CodingKeys: String, CodingKey {
        case id, key, name, site, type
        case language = "iso_639_1"
    }
}
