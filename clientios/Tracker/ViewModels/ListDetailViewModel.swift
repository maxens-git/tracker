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

    /// Métadonnées (affiche, titre, année) enrichies depuis TMDB, indexées par tmdbId.
    private(set) var meta: [Int: ItemMeta] = [:]

    struct ItemMeta {
        let posterPath: String?
        let title: String
        let year: String?
    }

    private var page = 1
    private let api = APIService.shared
    private let tmdb = TMDBService.shared

    init(listId: String) {
        self.listId = listId
    }

    /// Poster à afficher : celui stocké en base, sinon celui enrichi depuis TMDB.
    func posterPath(for item: MediaListItem) -> String? {
        item.posterPath ?? meta[item.tmdbId]?.posterPath
    }

    /// Titre enrichi depuis TMDB (vide tant que non chargé).
    func title(for item: MediaListItem) -> String {
        meta[item.tmdbId]?.title ?? ""
    }

    /// Année enrichie depuis TMDB.
    func year(for item: MediaListItem) -> String? {
        meta[item.tmdbId]?.year
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
            await enrichItems(result.items)
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    /// Récupère en parallèle, depuis TMDB, les métadonnées (affiche, titre, année)
    /// des items pas encore enrichis. Le backend ne stocke pas ces métadonnées.
    private func enrichItems(_ newItems: [MediaListItem]) async {
        let missing = newItems.filter { meta[$0.tmdbId] == nil }
        guard !missing.isEmpty else { return }
        let service = tmdb

        let fetched = await withTaskGroup(of: (Int, ItemMeta)?.self) { group -> [(Int, ItemMeta)] in
            for item in missing {
                let id = item.tmdbId
                let type = item.type
                group.addTask {
                    switch type {
                    case .movie:
                        guard let m = try? await service.movie(id) else { return nil }
                        return (id, ItemMeta(posterPath: m.posterPath, title: m.title,
                                             year: Self.yearString(m.releaseDate)))
                    case .tv:
                        guard let s = try? await service.show(id) else { return nil }
                        return (id, ItemMeta(posterPath: s.posterPath, title: s.name,
                                             year: Self.yearString(s.firstAirDate)))
                    }
                }
            }
            var results: [(Int, ItemMeta)] = []
            for await pair in group { if let pair { results.append(pair) } }
            return results
        }

        for (id, m) in fetched { meta[id] = m }
    }

    /// Extrait l'année (4 premiers caractères) d'une date TMDB "yyyy-MM-dd".
    private nonisolated static func yearString(_ date: String?) -> String? {
        guard let date, date.count >= 4 else { return nil }
        return String(date.prefix(4))
    }
}
