import Foundation

extension Error {
    var isCancellation: Bool { self is CancellationError }
}

@MainActor
final class APIService {
    static let shared = APIService()
    struct Call { let page: Int; let forceRefresh: Bool }
    var pages: [Int: [MediaListItem]] = [:]
    var calls: [Call] = []
    var failNext = false
    var suspendCalls: Set<Int> = []
    var suspended: [Int: CheckedContinuation<Void, Never>] = [:]

    func reset() {
        pages = [:]
        calls = []
        failNext = false
        suspendCalls = []
        suspended = [:]
    }

    func listItems(listId: String, page: Int, forceRefresh: Bool = false) async throws -> PaginatedResult<MediaListItem> {
        calls.append(Call(page: page, forceRefresh: forceRefresh))
        let number = calls.count
        if failNext {
            failNext = false
            throw URLError(.notConnectedToInternet)
        }
        let response = PaginatedResult(items: pages[page] ?? [], page: page, pageSize: 20,
                                       totalCount: pages.values.reduce(0) { $0 + $1.count }, totalPages: pages.count)
        if suspendCalls.contains(number) {
            // Intentionally ignores cancellation to exercise generation checks.
            await withCheckedContinuation { suspended[number] = $0 }
        }
        return response
    }

    func resume(_ call: Int) { suspended.removeValue(forKey: call)?.resume() }
}

struct MockMovie: Sendable { let posterPath: String? = nil; let title: String; let releaseDate: String? = nil }
struct MockShow: Sendable { let posterPath: String? = nil; let name: String; let firstAirDate: String? = nil }
struct TMDBService: Sendable {
    static let shared = TMDBService()
    nonisolated func movie(_ id: Int) async throws -> MockMovie { MockMovie(title: id == 21 ? "Target" : "Movie \(id)") }
    nonisolated func show(_ id: Int) async throws -> MockShow { MockShow(name: "Show \(id)") }
}

@main
struct ListRegressionTests {
    @MainActor static func item(_ id: Int, type: MediaType = .movie, seen: Bool = false) -> MediaListItem {
        MediaListItem(tmdbId: id, mediaType: type.rawValue, posterPath: nil, seen: seen,
                      watchCount: seen ? 1 : 0, liked: false, addedAt: nil)
    }

    @MainActor static func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<100_000 {
            if condition() { return }
            await Task.yield()
        }
        fatalError("Timed out waiting for test operation")
    }

    @MainActor static func main() async {
        let api = APIService.shared
        api.reset()
        api.pages = [1: [item(7), item(7, type: .tv)]]
        let mixed = ListDetailViewModel(listId: "1")
        await mixed.refresh()
        assert(Set(mixed.items.map(\.id)).count == 2)
        assert(mixed.meta.count == 2)
        assert(mixed.items.map { mixed.title(for: $0) } == ["Movie 7", "Show 7"])
        print("PASS: films and shows retain distinct identities and metadata")

        api.reset()
        api.pages = [1: (1...20).map { item($0) }, 2: [item(21)]]
        let search = ListDetailViewModel(listId: "watchlist")
        await search.refresh()
        assert(search.items.count == 20 && search.hasMore)
        search.query = "Target"
        assert(search.filteredItems.isEmpty)
        await search.loadSearchResults()
        assert(search.filteredItems.map(\.tmdbId) == [21] && !search.hasMore)
        print("PASS: title search reaches later pages without a visible pagination card")

        api.reset()
        api.pages = [1: [item(1)], 2: [item(2)]]
        let returning = ListDetailViewModel(listId: "watchlist")
        await returning.refresh()
        await returning.loadMore()
        api.pages = [1: [item(2, seen: true)]]
        api.suspendCalls = [3]
        let refresh = Task { await returning.refresh() }
        await waitUntil { api.suspended[3] != nil }
        assert(returning.items.map(\.tmdbId) == [1, 2])
        api.resume(3)
        await refresh.value
        assert(returning.items.map(\.tmdbId) == [2] && returning.items[0].seen)
        assert(api.calls[2].forceRefresh)
        print("PASS: refresh preserves current content then reconciles removals and state")

        api.reset()
        api.pages = [1: [item(1)]]
        api.failNext = true
        let retry = ListDetailViewModel(listId: "watchlist")
        await retry.refresh()
        assert(retry.items.isEmpty && retry.errorMessage != nil && !retry.isLoading)
        await retry.refresh()
        assert(retry.items.count == 1 && retry.errorMessage == nil)
        print("PASS: a failed initial load can be retried")

        api.reset()
        api.pages = [1: [item(1)]]
        api.suspendCalls = [1]
        let cancelled = ListDetailViewModel(listId: "watchlist")
        let initial = Task { await cancelled.refresh() }
        await waitUntil { api.suspended[1] != nil }
        initial.cancel()
        api.resume(1)
        await initial.value
        assert(cancelled.items.isEmpty && cancelled.errorMessage == nil && !cancelled.isLoading)
        await cancelled.refresh()
        assert(cancelled.items.count == 1)
        print("PASS: a cancelled initial load is retried on return")

        api.reset()
        api.pages = [1: [item(1)]]
        api.suspendCalls = [1]
        let latest = ListDetailViewModel(listId: "watchlist")
        let stale = Task { await latest.refresh() }
        await waitUntil { api.suspended[1] != nil }
        api.pages = [1: [item(2)]]
        await latest.refresh()
        api.resume(1)
        await stale.value
        assert(latest.items.map(\.tmdbId) == [2] && !latest.isLoading)
        print("PASS: a stale response cannot overwrite a newer refresh")

        api.reset()
        api.pages = [1: [item(1)], 2: [item(2)]]
        let pagination = ListDetailViewModel(listId: "watchlist")
        await pagination.refresh()
        api.failNext = true
        await pagination.loadMore()
        assert(pagination.items.map(\.tmdbId) == [1] && pagination.errorMessage != nil)
        await pagination.retry()
        assert(api.calls.map(\.page) == [1, 2, 2])
        assert(pagination.items.map(\.tmdbId) == [1, 2] && pagination.errorMessage == nil)
        print("PASS: retry requests the failed next page without restarting the list")

        api.reset()
        api.pages = [1: [item(1)], 2: [item(21)]]
        let clearedSearch = ListDetailViewModel(listId: "watchlist")
        await clearedSearch.refresh()
        api.suspendCalls = [2]
        clearedSearch.query = "Target"
        let searching = Task { await clearedSearch.loadSearchResults() }
        await waitUntil { api.suspended[2] != nil }
        searching.cancel()
        clearedSearch.query = ""
        await clearedSearch.loadMore() // The reappearing card is still waiting on cancellation.
        api.resume(2)
        await searching.value
        assert(clearedSearch.hasMore && !clearedSearch.isLoading)
        await clearedSearch.loadMore() // Explicit "Charger la suite" remains available.
        assert(clearedSearch.items.map(\.tmdbId) == [1, 21] && !clearedSearch.hasMore)
        print("PASS: pagination can resume after clearing an in-flight search")
    }
}
