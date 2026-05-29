//
//  PersonViewModel.swift
//  Tracker
//

import Foundation

/// Une œuvre de la filmographie d'une personne, enrichie de l'état "vu".
struct FilmographyItem: Identifiable, Hashable {
    let tmdbId: Int
    let type: MediaType
    let title: String
    let year: String?
    let posterPath: String?
    var seen: Bool

    var id: String { "\(type.rawValue)-\(tmdbId)" }
}

@Observable
@MainActor
final class PersonViewModel {
    let personId: Int

    private(set) var person: TMDBPerson?
    private(set) var filmography: [FilmographyItem] = []
    private(set) var isLoading = false
    var errorMessage: String?

    private let tmdb = TMDBService.shared
    private let api = APIService.shared

    init(personId: Int) {
        self.personId = personId
    }

    // ── Champs dérivés ────────────────────────────────────────────────────

    var name: String { person?.name ?? "" }
    var department: String? { person?.knownForDepartment }
    var biography: String? { person?.biography }
    var profilePath: String? { person?.profilePath }
    var placeOfBirth: String? { person?.placeOfBirth }

    var birthday: String? { Self.displayDate(person?.birthday) }
    var deathday: String? { Self.displayDate(person?.deathday) }

    /// Âge (à la date du décès si renseignée, sinon aujourd'hui).
    var age: Int? {
        guard let raw = person?.birthday, let birth = Self.dayParser.date(from: raw) else { return nil }
        let end = person?.deathday.flatMap { Self.dayParser.date(from: $0) } ?? Date()
        return Calendar.current.dateComponents([.year], from: birth, to: end).year
    }

    // ── Chargement ────────────────────────────────────────────────────────

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            person = try await tmdb.person(personId)
            let credits = try await tmdb.personCombinedCredits(personId)
            let items = buildFilmography(credits.cast)
            filmography = await enrichWithStates(items)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Films + séries (rôles d'acteur) : dédoublonnés, avec affiche, du plus récent au plus ancien.
    private func buildFilmography(_ cast: [TMDBPersonCredit]) -> [FilmographyItem] {
        var byKey: [String: FilmographyItem] = [:]
        var order: [String] = []

        for credit in cast {
            guard let raw = credit.mediaTypeRaw, raw == "movie" || raw == "tv" else { continue }
            guard let poster = credit.posterPath, !poster.isEmpty else { continue }

            let type: MediaType = raw == "tv" ? .tv : .movie
            let key = "\(raw)-\(credit.id)"
            guard byKey[key] == nil else { continue }

            let date = credit.releaseDate ?? credit.firstAirDate
            let year = (date?.count ?? 0) >= 4 ? String(date!.prefix(4)) : nil

            byKey[key] = FilmographyItem(
                tmdbId: credit.id,
                type: type,
                title: credit.title ?? credit.name ?? "Sans titre",
                year: year,
                posterPath: poster,
                seen: false
            )
            order.append(key)
        }

        return order.compactMap { byKey[$0] }
            .sorted { ($0.year ?? "") > ($1.year ?? "") }
    }

    /// Renseigne l'état "vu" sur la filmographie.
    private func enrichWithStates(_ items: [FilmographyItem]) async -> [FilmographyItem] {
        let movieIds = items.filter { $0.type == .movie }.map(\.tmdbId)
        let showIds = items.filter { $0.type == .tv }.map(\.tmdbId)

        async let movieStates = api.states(tmdbIds: movieIds, type: .movie)
        async let showStates = api.states(tmdbIds: showIds, type: .tv)

        let movies = (try? await movieStates) ?? []
        let shows = (try? await showStates) ?? []
        let seenIds = Set((movies + shows).filter(\.seen).map(\.tmdbId))

        return items.map { item in
            var copy = item
            copy.seen = seenIds.contains(item.tmdbId)
            return copy
        }
    }

    // ── Formatage des dates ───────────────────────────────────────────────

    private static let dayParser: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateStyle = .long
        f.timeStyle = .none
        return f
    }()

    private static func displayDate(_ raw: String?) -> String? {
        guard let raw, let date = dayParser.date(from: raw) else { return nil }
        return displayFormatter.string(from: date)
    }
}
