//
//  ShowtimesViewModel.swift
//  Tracker
//
//  Séances de cinéma : consultation d'une ou plusieurs salles pour une date,
//  regroupées par film (chaque séance rattachée à sa salle), avec listes de
//  cinémas sauvegardées et liste par défaut. En miroir de la page Séances web.
//

import Foundation

/// Les séances d'un film dans une salle donnée.
struct MovieTheaterShows: Identifiable, Hashable {
    let theater: Theater
    let shows: [Showtime]
    var id: String { theater.code }
}

/// Un film agrégé sur toutes les salles consultées, avec ses séances par salle.
struct MergedMovie: Identifiable, Hashable {
    let id: String        // clé stable (id Allociné ou titre)
    let movieId: Int?
    let title: String
    let poster: String?
    let runtime: String?
    let genres: [String]
    let url: String?
    let byTheater: [MovieTheaterShows]
}

@Observable
@MainActor
final class ShowtimesViewModel {
    // Cinéma affiché par défaut en mode « cinéma unique » (Pathé Toulouse Wilson).
    static let defaultTheater = "P0057"

    private(set) var lists: [TheaterList] = []
    /// Liste sélectionnée ; `nil` = mode « cinéma unique » (ad hoc).
    private(set) var selectedListId: Int?
    var adhocTheater = defaultTheater

    var pickedDate = Date()

    private(set) var programs: [TheaterShowtimes] = []
    private(set) var isLoading = false
    private(set) var loaded = false
    var errorMessage: String?

    /// Noms de salles connus (code → nom), alimentés par les programmes chargés.
    private var theaterNames: [String: String] = [:]

    private let api = APIService.shared
    private let calendar = Calendar.current

    /// Aujourd'hui à minuit : borne basse (pas de séance dans le passé).
    let today = Calendar.current.startOfDay(for: Date())

    var selectedList: TheaterList? { lists.first { $0.id == selectedListId } }
    var isAdhoc: Bool { selectedListId == nil }
    var canGoPrev: Bool { calendar.startOfDay(for: pickedDate) > today }

    // ── Cycle de vie ──────────────────────────────────────────────────────

    func start() async {
        if lists.isEmpty && !loaded {
            await reloadLists(select: nil, autoDefault: true)
        }
        await load()
    }

    /// Recharge les listes ; sélectionne `select` si fourni, sinon la liste par défaut
    /// (au premier chargement seulement) puis « cinéma unique ».
    private func reloadLists(select: Int?, autoDefault: Bool) async {
        do {
            let fetched = try await api.theaterLists()
            lists = fetched
            if let select, fetched.contains(where: { $0.id == select }) {
                selectedListId = select
            } else if autoDefault, let def = fetched.first(where: { $0.isDefault }) {
                selectedListId = def.id
            } else if select == nil && !fetched.contains(where: { $0.id == selectedListId }) {
                selectedListId = nil
            }
        } catch {
            // Pas de listes chargées → on reste en mode « cinéma unique ».
        }
    }

    // ── Chargement des séances ────────────────────────────────────────────

    private var activeCodes: [String] {
        if let list = selectedList { return list.codes }
        let code = adhocTheater.trimmingCharacters(in: .whitespaces).uppercased()
        return code.isEmpty ? [] : [code]
    }

    func load() async {
        let codes = activeCodes
        guard !codes.isEmpty, !isLoading else { return }

        isLoading = true
        errorMessage = nil
        do {
            let result = try await api.multiShowtimes(codes: codes, date: isoDate(pickedDate))
            for prog in result where prog.theater.name != nil {
                theaterNames[prog.theater.code] = prog.theater.name
            }
            programs = result
        } catch {
            if !error.isCancellation {
                programs = []
                errorMessage = error.localizedDescription
            }
        }
        loaded = true
        isLoading = false
    }

    func selectList(_ id: Int?) {
        guard id != selectedListId else { return }
        selectedListId = id
        programs = []
        loaded = false
        Task { await load() }
    }

    /// Décale d'un jour (borné à aujourd'hui). Le rechargement est déclenché par
    /// l'observation de `pickedDate` côté vue, qui couvre aussi le sélecteur de date.
    func shiftDay(_ delta: Int) {
        guard let next = calendar.date(byAdding: .day, value: delta, to: pickedDate) else { return }
        if calendar.startOfDay(for: next) < today { return } // pas de jour antérieur à aujourd'hui
        pickedDate = next
    }

    // ── Fusion par film ───────────────────────────────────────────────────

    var mergedMovies: [MergedMovie] { Self.merge(programs) }

    /// Signature d'une séance indépendante de son id : deux séances de même horaire,
    /// version et format sont considérées identiques (Allociné duplique parfois).
    private static func signature(_ s: Showtime) -> String {
        "\(s.iso)|\(s.version ?? "")|\(s.formats.sorted().joined(separator: ","))"
    }

    private static func merge(_ programs: [TheaterShowtimes]) -> [MergedMovie] {
        struct Acc {
            var id: Int?
            var title: String
            var poster: String?
            var runtime: String?
            var genres: [String]
            var url: String?
            var byTheater: [MovieTheaterShows]
            var earliest: String
        }
        var order: [String] = []
        var accs: [String: Acc] = [:]

        for prog in programs {
            for movie in prog.movies where !movie.shows.isEmpty {
                let key = movie.id.map { "m:\($0)" } ?? "t:\(movie.title)"
                if accs[key] == nil {
                    accs[key] = Acc(id: movie.id, title: movie.title, poster: movie.poster,
                                    runtime: movie.runtime, genres: movie.genres, url: movie.url,
                                    byTheater: [], earliest: movie.shows[0].iso)
                    order.append(key)
                } else if accs[key]!.poster == nil, let p = movie.poster {
                    accs[key]!.poster = p
                }

                // Regroupe par salle, en dédupliquant les séances par signature.
                if let idx = accs[key]!.byTheater.firstIndex(where: { $0.theater.code == prog.theater.code }) {
                    var shows = accs[key]!.byTheater[idx].shows
                    var seen = Set(shows.map(signature))
                    for s in movie.shows where seen.insert(signature(s)).inserted { shows.append(s) }
                    shows.sort { $0.iso < $1.iso }
                    accs[key]!.byTheater[idx] = MovieTheaterShows(theater: prog.theater, shows: shows)
                } else {
                    accs[key]!.byTheater.append(MovieTheaterShows(theater: prog.theater, shows: movie.shows))
                }
                if movie.shows[0].iso < accs[key]!.earliest { accs[key]!.earliest = movie.shows[0].iso }
            }
        }

        return order.map { key -> (MergedMovie, String) in
            let a = accs[key]!
            let groups = a.byTheater.sorted {
                $0.theater.label.localizedCompare($1.theater.label) == .orderedAscending
            }
            return (MergedMovie(id: key, movieId: a.id, title: a.title, poster: a.poster,
                                runtime: a.runtime, genres: a.genres, url: a.url, byTheater: groups),
                    a.earliest)
        }
        .sorted { $0.1 < $1.1 }
        .map(\.0)
    }

    // ── Gestion des listes ────────────────────────────────────────────────

    /// Crée (id nil) ou met à jour une liste, puis la sélectionne. Renvoie true si réussi.
    func saveList(id: Int?, name: String, codes: [String]) async -> Bool {
        do {
            let saved: TheaterList
            if let id {
                saved = try await api.updateTheaterList(id: id, name: name, codes: codes)
            } else {
                saved = try await api.createTheaterList(name: name, codes: codes)
            }
            await reloadLists(select: saved.id, autoDefault: false)
            programs = []
            loaded = false
            await load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteSelected() async {
        guard let list = selectedList else { return }
        do {
            try await api.deleteTheaterList(id: list.id)
            selectedListId = nil
            await reloadLists(select: nil, autoDefault: false)
            programs = []
            loaded = false
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setDefaultSelected() async {
        guard let list = selectedList, !list.isDefault else { return }
        do {
            try await api.setDefaultTheaterList(id: list.id)
            await reloadLists(select: list.id, autoDefault: false)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // ── Libellés ──────────────────────────────────────────────────────────

    /// Nom de salle connu pour un code (issu des programmes chargés), sinon le code.
    func codeLabel(_ code: String) -> String { theaterNames[code] ?? code }

    /// Date sélectionnée au format YYYY-MM-DD (fuseau local).
    private func isoDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
