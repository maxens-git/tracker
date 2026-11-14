//
//  ListDetailViewModel.swift
//  Tracker
//

import Foundation
import Observation

@Observable
@MainActor
final class ListDetailViewModel {
    /// Identifiant de liste : numérique ou alias système ("seen", "liked", "watchlist").
    let listId: String

    private(set) var items: [MediaListItem] = []
    private(set) var isLoading = false
    private(set) var hasMore = true
    var errorMessage: String?
    var query = ""

    var isSearching: Bool { !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var filteredItems: [MediaListItem] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return items }
        return items.filter { title(for: $0).localizedStandardContains(text) }
    }

    /// TMDB utilise des identifiants distincts par type de média.
    private(set) var meta: [String: ItemMeta] = [:]

    struct ItemMeta: Sendable {
        let posterPath: String?
        let title: String
        let year: String?
    }

    private var page = 1
    private var generation = 0
    private var failedRequestWasRefresh = true
    private var loadingTask: Task<Void, Never>?
    private let api = APIService.shared
    private let tmdb = TMDBService.shared

    init(listId: String) {
        self.listId = listId
    }

    func posterPath(for item: MediaListItem) -> String? {
        item.posterPath ?? meta[item.id]?.posterPath
    }

    func title(for item: MediaListItem) -> String {
        meta[item.id]?.title ?? ""
    }

    func year(for item: MediaListItem) -> String? {
        meta[item.id]?.year
    }

    /// Réconcilie toutes les pages déjà affichées au retour d'une fiche. Le contenu
    /// reste en place pendant la requête, pour conserver la position de défilement.
    func refresh() async {
        loadingTask?.cancel()
        generation += 1
        await startLoading(refresh: true)
    }

    func loadMore() async {
        guard hasMore, loadingTask == nil else { return }
        await startLoading(refresh: false)
    }

    /// Rejoue la page en échec, sans perdre les pages déjà affichées.
    func retry() async {
        if failedRequestWasRefresh {
            await refresh()
        } else {
            await loadMore()
        }
    }

    /// Une recherche charge la suite même si le filtre masque la dernière carte.
    /// Attend la requête précédente, notamment celle annulée par un changement de texte.
    func loadSearchResults() async {
        guard isSearching else { return }
        if let loadingTask { await loadingTask.value }
        guard !Task.isCancelled, isSearching, hasMore, errorMessage == nil else { return }
        await loadMore()
    }

    private func startLoading(refresh: Bool) async {
        let requestGeneration = generation
        isLoading = true
        errorMessage = nil
        let task = Task { await fetchPages(refresh: refresh, generation: requestGeneration) }
        loadingTask = task
        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private func fetchPages(refresh: Bool, generation requestGeneration: Int) async {
        defer {
            if requestGeneration == generation {
                loadingTask = nil
                isLoading = false
            }
        }

        let lastPageToRefresh = max(1, page - 1)
        var nextPage = refresh ? 1 : page
        var refreshedItems: [MediaListItem] = []
        var more = hasMore
        do {
            repeat {
                let result = try await api.listItems(listId: listId, page: nextPage, forceRefresh: refresh)
                try Task.checkCancellation()
                guard requestGeneration == generation else { return }
                let metadata = await fetchMetadata(for: result.items)
                try Task.checkCancellation()
                guard requestGeneration == generation else { return }

                meta.merge(metadata) { _, new in new }
                if refresh {
                    appendUnique(result.items, to: &refreshedItems)
                } else {
                    appendUnique(result.items, to: &items)
                }
                more = nextPage < result.totalPages
                nextPage += 1
                if !refresh {
                    page = nextPage
                    hasMore = more
                }
            } while more && ((refresh && nextPage <= lastPageToRefresh) || isSearching)

            if refresh {
                items = refreshedItems
                page = nextPage
                hasMore = more
            }
        } catch {
            guard requestGeneration == generation else { return }
            if !error.isCancellation {
                failedRequestWasRefresh = refresh
                errorMessage = error.localizedDescription
            }
        }
    }

    private func appendUnique(_ newItems: [MediaListItem], to destination: inout [MediaListItem]) {
        var ids = Set(destination.map(\.id))
        destination.append(contentsOf: newItems.filter { ids.insert($0.id).inserted })
    }

    private func fetchMetadata(for newItems: [MediaListItem]) async -> [String: ItemMeta] {
        let missing = newItems.filter { meta[$0.id] == nil }
        let service = tmdb
        return await withTaskGroup(of: (String, ItemMeta)?.self) { group in
            for item in missing {
                let id = item.tmdbId
                let key = item.id
                let type = item.type
                group.addTask {
                    switch type {
                    case .movie:
                        guard let movie = try? await service.movie(id) else { return nil }
                        return (key, ItemMeta(posterPath: movie.posterPath, title: movie.title,
                                              year: Self.yearString(movie.releaseDate)))
                    case .tv:
                        guard let show = try? await service.show(id) else { return nil }
                        return (key, ItemMeta(posterPath: show.posterPath, title: show.name,
                                              year: Self.yearString(show.firstAirDate)))
                    }
                }
            }
            var result: [String: ItemMeta] = [:]
            for await pair in group { if let (key, value) = pair { result[key] = value } }
            return result
        }
    }

    private nonisolated static func yearString(_ date: String?) -> String? {
        guard let date, date.count >= 4 else { return nil }
        return String(date.prefix(4))
    }
}
