//
//  ListDetailViewModel.swift
//  Tracker
//

import Foundation

@Observable
@MainActor
final class ListDetailViewModel {
    /// Identifiant de liste : numérique ou alias système ("seen", "liked", "watchlist").
    let listId: String

    private(set) var items: [MediaListItem] = []
    private(set) var isLoading = false
    private(set) var hasMore = true
    var errorMessage: String?

    /// Posters récupérés depuis TMDB pour les items sans posterPath en base.
    private(set) var posters: [Int: String] = [:]

    private var page = 1
    private let api = APIService.shared
    private let tmdb = TMDBService.shared

    init(listId: String) {
        self.listId = listId
    }

    /// Poster à afficher : celui stocké en base, sinon celui enrichi depuis TMDB.
    func posterPath(for item: MediaListItem) -> String? {
        item.posterPath ?? posters[item.tmdbId]
    }

    func loadFirstPage() async {
        page = 1
        items = []
        hasMore = true
        await loadMore()
    }

    func loadMore() async {
        guard hasMore, !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            let result = try await api.listItems(listId: listId, page: page)
            items.append(contentsOf: result.items)
            hasMore = page < result.totalPages
            page += 1
            isLoading = false
            await enrichPosters(result.items)
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    /// Récupère en parallèle les posters TMDB des items qui n'en ont pas en base.
    private func enrichPosters(_ newItems: [MediaListItem]) async {
        let missing = newItems.filter { $0.posterPath == nil && posters[$0.tmdbId] == nil }
        guard !missing.isEmpty else { return }
        let service = tmdb

        let fetched = await withTaskGroup(of: (Int, String?).self) { group -> [(Int, String?)] in
            for item in missing {
                let id = item.tmdbId
                let type = item.type
                group.addTask {
                    let path: String?
                    switch type {
                    case .movie: path = try? await service.movie(id).posterPath
                    case .tv:    path = try? await service.show(id).posterPath
                    }
                    return (id, path)
                }
            }
            var results: [(Int, String?)] = []
            for await pair in group { results.append(pair) }
            return results
        }

        for (id, path) in fetched where path != nil {
            posters[id] = path
        }
    }
}
