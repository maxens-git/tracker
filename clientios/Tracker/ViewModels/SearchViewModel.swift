//
//  SearchViewModel.swift
//  Tracker
//

import Foundation

@Observable
@MainActor
final class SearchViewModel {
    var query = ""
    private(set) var allResults: [TMDBSearchResult] = []
    private(set) var isLoading = false
    var errorMessage: String?

    /// Filtre de type : nil = Tout, sinon film ou série.
    var filter: MediaType?

    /// Résultats filtrés par type (film / série / tout).
    var results: [TMDBSearchResult] {
        guard let filter else { return allResults }
        return allResults.filter { $0.mediaType == filter }
    }

    var movieCount: Int { allResults.filter { $0.mediaType == .movie }.count }
    var showCount: Int { allResults.filter { $0.mediaType == .tv }.count }

    /// Clés ("movie-123" / "tv-123") des médias déjà vus, pour le badge sur l'affiche.
    private(set) var seenKeys: Set<String> = []

    private let tmdb = TMDBService.shared
    private let api = APIService.shared
    private var searchTask: Task<Void, Never>?

    func isSeen(_ result: TMDBSearchResult) -> Bool {
        seenKeys.contains("\(result.mediaType.rawValue)-\(result.id)")
    }

    /// Lance une recherche debouncée (300 ms) sur la requête courante.
    func search() {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

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
            let response = try await tmdb.searchMulti(text)
            guard !Task.isCancelled else { return }
            // On ne garde que films et séries (pas les personnes).
            allResults = response.results.filter {
                $0.mediaTypeRaw == nil || $0.mediaTypeRaw == "movie" || $0.mediaTypeRaw == "tv"
            }
            seenKeys = await api.seenStateKeys(for: allResults)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
