//
//  SearchViewModel.swift
//  Tracker
//

import Foundation

@Observable
@MainActor
final class SearchViewModel {
    var query = ""
    private(set) var results: [TMDBSearchResult] = []
    private(set) var isLoading = false
    var errorMessage: String?

    private let tmdb = TMDBService.shared
    private var searchTask: Task<Void, Never>?

    /// Lance une recherche debouncée (300 ms) sur la requête courante.
    func search() {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            results = []
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
            results = response.results.filter {
                $0.mediaTypeRaw == nil || $0.mediaTypeRaw == "movie" || $0.mediaTypeRaw == "tv"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
