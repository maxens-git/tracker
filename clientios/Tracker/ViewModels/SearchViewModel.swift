//
//  SearchViewModel.swift
//  Tracker
//

import Foundation

/// Critère de tri appliqué côté client sur les résultats de recherche.
enum SearchSort: String, CaseIterable, Identifiable {
    case relevance      // ordre TMDB d'origine (pertinence)
    case ratingDesc     // note décroissante
    case dateDesc       // plus récent d'abord
    case dateAsc        // plus ancien d'abord
    case popularityDesc // popularité décroissante

    var id: String { rawValue }

    var label: String {
        switch self {
        case .relevance:      return "Pertinence"
        case .ratingDesc:     return "Note"
        case .dateDesc:       return "Plus récent"
        case .dateAsc:        return "Plus ancien"
        case .popularityDesc: return "Popularité"
        }
    }
}

@Observable
@MainActor
final class SearchViewModel {
    var query = ""
    private(set) var allResults: [TMDBSearchResult] = []
    private(set) var isLoading = false
    var errorMessage: String?

    /// Filtre de type : nil = Tout, sinon film ou série.
    var filter: MediaType?

    /// Genres disponibles (chargés une fois depuis TMDB) pour proposer des filtres.
    private(set) var availableGenres: [TMDBGenre] = []

    /// Genres sélectionnés (ids TMDB) ; un résultat passe s'il a au moins un de ces genres.
    var selectedGenreIds: Set<Int> = []

    /// Tri courant appliqué aux résultats.
    var sort: SearchSort = .relevance

    /// Vrai si au moins un filtre genre ou un tri non par défaut est actif.
    var hasActiveFilters: Bool { !selectedGenreIds.isEmpty || sort != .relevance }

    /// Genres effectivement présents dans les résultats courants (pour ne proposer
    /// que des filtres utiles). Conserve l'ordre alphabétique d'`availableGenres`.
    var relevantGenres: [TMDBGenre] {
        let present = Set(allResults.flatMap { $0.genreIds ?? [] })
        return availableGenres.filter { present.contains($0.id) }
    }

    /// Résultats après filtre de type, filtre de genres et tri (tout côté client).
    var results: [TMDBSearchResult] {
        var items = allResults
        if let filter { items = items.filter { $0.mediaType == filter } }
        if !selectedGenreIds.isEmpty {
            items = items.filter { result in
                guard let ids = result.genreIds else { return false }
                return !selectedGenreIds.isDisjoint(with: ids)
            }
        }
        return sorted(items)
    }

    /// Compteurs par type calculés sur l'ensemble (avant filtre de type).
    var movieCount: Int { allResults.filter { $0.mediaType == .movie }.count }
    var showCount: Int { allResults.filter { $0.mediaType == .tv }.count }

    /// Clés ("movie-123" / "tv-123") des médias déjà vus, pour le badge sur l'affiche.
    private(set) var seenKeys: Set<String> = []

    /// Historique des recherches récentes (local, persisté).
    let history = SearchHistoryStore()

    private let tmdb = TMDBService.shared
    private let api = APIService.shared
    private var searchTask: Task<Void, Never>?

    /// Nombre de pages TMDB récupérées par recherche (20 résultats chacune).
    /// Une seule page ne laissait presque rien aux filtres type/genre une fois
    /// les personnes retirées ; trois pages sont demandées en parallèle, donc
    /// sans coût de latence notable.
    private let pagesPerSearch = 3

    func isSeen(_ result: TMDBSearchResult) -> Bool {
        seenKeys.contains("\(result.mediaType.rawValue)-\(result.id)")
    }

    /// Charge la liste des genres une seule fois (silencieux en cas d'échec).
    func loadGenresIfNeeded() async {
        guard availableGenres.isEmpty else { return }
        availableGenres = (try? await tmdb.allGenres()) ?? []
    }

    /// Réinitialise les filtres genre et le tri.
    func resetFilters() {
        selectedGenreIds = []
        sort = .relevance
    }

    /// Applique le tri choisi à une liste de résultats.
    private func sorted(_ items: [TMDBSearchResult]) -> [TMDBSearchResult] {
        switch sort {
        case .relevance:
            return items
        case .ratingDesc:
            return items.sorted { ($0.voteAverage ?? 0) > ($1.voteAverage ?? 0) }
        case .popularityDesc:
            return items.sorted { ($0.popularity ?? 0) > ($1.popularity ?? 0) }
        case .dateDesc:
            return items.sorted { sortDate($0) > sortDate($1) }
        case .dateAsc:
            return items.sorted { sortDate($0) < sortDate($1) }
        }
    }

    /// Date de sortie/diffusion utilisée pour le tri (chaîne "AAAA-MM-JJ", vide en dernier).
    private func sortDate(_ result: TMDBSearchResult) -> String {
        result.releaseDate ?? result.firstAirDate ?? ""
    }

    /// Lance une recherche debouncée (300 ms).
    ///
    /// Le texte est passé explicitement plutôt que relu dans `query` : la valeur
    /// notifiée par `onChange` est la seule dont on sait qu'elle correspond à la
    /// frappe qui a déclenché l'appel.
    ///
    /// Depuis que l'onglet Recherche est un `Tab(role: .search)`, le champ est
    /// hébergé par la barre d'onglets et non par cette vue : l'écriture du
    /// binding et la notification `onChange` n'arrivent plus dans le même ordre,
    /// et relire la propriété donnait la frappe précédente — « Dune » affiché à
    /// l'écran, résultats de « dun ».
    func search(_ text: String? = nil) {
        searchTask?.cancel()
        let trimmed = (text ?? query).trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            allResults = []
            isLoading = false
            return
        }

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await performSearch(trimmed)
        }
    }

    private func performSearch(_ text: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await tmdb.searchMulti(text, pages: pagesPerSearch)
            guard !Task.isCancelled else { return }
            // On ne garde que films et séries (pas les personnes).
            let media = fetched.filter {
                $0.mediaTypeRaw == nil || $0.mediaTypeRaw == "movie" || $0.mediaTypeRaw == "tv"
            }
            // Dédoublonnage (une même fiche peut revenir d'une page à l'autre)
            // puis reclassement : l'ordre TMDB privilégie la popularité, pas la
            // correspondance avec ce qui a été tapé.
            allResults = SearchRanking.rank(SearchRanking.deduplicated(media), query: text)
            // La recherche a abouti : on l'ajoute à l'historique récent.
            if !allResults.isEmpty { history.record(text) }
            seenKeys = await api.seenStateKeys(for: allResults)
        } catch {
            if !error.isCancellation { errorMessage = error.localizedDescription }
        }
        isLoading = false
    }
}
