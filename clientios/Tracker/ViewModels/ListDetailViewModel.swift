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

    private var page = 1
    private let api = APIService.shared

    init(listId: String) {
        self.listId = listId
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
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
