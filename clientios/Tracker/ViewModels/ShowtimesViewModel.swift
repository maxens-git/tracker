//
//  ShowtimesViewModel.swift
//  Tracker
//
//  Séances de cinéma : consultation des cinémas enregistrés pour une date,
//  regroupées par film (chaque séance rattachée à sa salle). Chaque cinéma est
//  coché ou non (état mémorisé) ; on peut en ajouter / retirer. Miroir de la
//  page Séances web.
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
    /// Cinémas enregistrés (liste plate) ; chacun coché ou non (état mémorisé côté serveur).
    private(set) var favorites: [FavoriteTheater] = []

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

    var canGoPrev: Bool { calendar.startOfDay(for: pickedDate) > today }

    /// Nombre de cinémas cochés (pour le sous-titre).
    var activeCount: Int { favorites.filter(\.isActive).count }

    /// Codes des cinémas cochés : détermine les salles affichées.
    private var activeCodes: Set<String> { Set(favorites.filter(\.isActive).map(\.code)) }

    // ── Cycle de vie ──────────────────────────────────────────────────────

    func start() async {
        if favorites.isEmpty && !loaded {
            await reloadFavorites()
        }
        await load()
    }

    private func reloadFavorites() async {
        do {
            favorites = try await api.favoriteTheaters()
        } catch {
            // Échec réseau : on remonte l'erreur plutôt que de la masquer, sinon la page
            // affiche « Aucun cinéma enregistré » comme si la liste était vide alors que
            // la requête a simplement planté (ex. serveur de dev éteint).
            if !error.isCancellation {
                errorMessage = error.localizedDescription
            }
        }
    }

    // ── Chargement des séances ────────────────────────────────────────────

    /// On charge tous les cinémas enregistrés en une requête ; le filtrage coché/décoché
    /// se fait à l'affichage, pour un basculement instantané sans rechargement.
    func load() async {
        let codes = favorites.map(\.code)
        guard !isLoading else { return }
        guard !codes.isEmpty else { programs = []; loaded = true; return }

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

    /// Décale d'un jour (borné à aujourd'hui). Le rechargement est déclenché par
    /// l'observation de `pickedDate` côté vue, qui couvre aussi le sélecteur de date.
    func shiftDay(_ delta: Int) {
        guard let next = calendar.date(byAdding: .day, value: delta, to: pickedDate) else { return }
        if calendar.startOfDay(for: next) < today { return } // pas de jour antérieur à aujourd'hui
        pickedDate = next
    }

    // ── Cinémas : cocher / décocher, ajouter, retirer ─────────────────────

    /// Coche / décoche un cinéma : affichage instantané, choix mémorisé côté serveur.
    func toggleActive(_ favorite: FavoriteTheater) {
        let next = !favorite.isActive
        setActiveLocally(id: favorite.id, isActive: next)
        Task {
            do {
                try await api.setFavoriteTheaterActive(id: favorite.id, isActive: next)
            } catch {
                setActiveLocally(id: favorite.id, isActive: !next) // rétablit en cas d'échec
                errorMessage = error.localizedDescription
            }
        }
    }

    private func setActiveLocally(id: Int, isActive: Bool) {
        guard let idx = favorites.firstIndex(where: { $0.id == id }) else { return }
        let f = favorites[idx]
        favorites[idx] = FavoriteTheater(id: f.id, code: f.code, isActive: isActive, position: f.position)
    }

    /// Ajoute un cinéma aux favoris par son code, puis recharge les séances. Renvoie true si réussi.
    @discardableResult
    func addFavorite(code: String) async -> Bool {
        let normalized = code.trimmingCharacters(in: .whitespaces).uppercased()
        guard !normalized.isEmpty else { return false }
        if favorites.contains(where: { $0.code == normalized }) {
            errorMessage = "Ce cinéma est déjà enregistré."
            return false
        }
        do {
            let added = try await api.addFavoriteTheater(code: normalized)
            if !favorites.contains(where: { $0.id == added.id }) { favorites.append(added) }
            await load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func removeFavorite(_ favorite: FavoriteTheater) async {
        do {
            try await api.removeFavoriteTheater(id: favorite.id)
            favorites.removeAll { $0.id == favorite.id }
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // ── Fusion par film ───────────────────────────────────────────────────

    /// Films affichés : on ne garde que les salles cochées et les films qui en gardent au moins une.
    var mergedMovies: [MergedMovie] {
        let active = activeCodes
        let all = Self.merge(programs)
        return all.compactMap { movie in
            let groups = movie.byTheater.filter { active.contains($0.theater.code) }
            guard !groups.isEmpty else { return nil }
            return MergedMovie(id: movie.id, movieId: movie.movieId, title: movie.title,
                               poster: movie.poster, runtime: movie.runtime, genres: movie.genres,
                               url: movie.url, byTheater: groups)
        }
    }

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
