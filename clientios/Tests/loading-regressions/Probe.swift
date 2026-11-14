import Foundation
import Observation

// Only the network boundary is replaced. The runner appends the production
// view models and cinema DTOs unchanged to this executable.
extension Error {
    var isCancellation: Bool { self is CancellationError }
}

struct SystemLog: Decodable {
    let id: Int
    let level: String
}

struct PaginatedResult<T: Decodable>: Decodable {
    let items: [T]
    let totalPages: Int
    let totalCount: Int
}

enum ProbeError: Error { case oldRequestFailed }

@MainActor
final class APIService {
    static let shared = APIService()

    struct ShowtimesRequest {
        let date: String
        let continuation: CheckedContinuation<[TheaterShowtimes], any Error>

        func succeed() {
            continuation.resume(returning: [TheaterShowtimes(
                theater: Theater(code: "TEST", name: "Test", address: nil,
                                 postalCode: nil, city: nil, image: nil),
                date: date, nextDate: nil, movies: [])])
        }
    }

    struct LogsRequest {
        let page: Int
        let level: String
        let search: String
        let continuation: CheckedContinuation<PaginatedResult<SystemLog>, any Error>

        func succeed(id: Int, totalPages: Int = 3) {
            continuation.resume(returning: PaginatedResult(
                items: [SystemLog(id: id, level: level)],
                totalPages: totalPages, totalCount: totalPages))
        }
    }

    var showtimesRequests: [ShowtimesRequest] = []
    var logsRequests: [LogsRequest] = []

    func favoriteTheaters() async throws -> [FavoriteTheater] {
        [FavoriteTheater(id: 1, code: "TEST", isActive: true, position: 0)]
    }

    func multiShowtimes(codes: [String], date: String?) async throws -> [TheaterShowtimes] {
        try await withCheckedThrowingContinuation {
            showtimesRequests.append(ShowtimesRequest(date: date!, continuation: $0))
        }
    }

    func setFavoriteTheaterActive(id: Int, isActive: Bool) async throws {}
    func removeFavoriteTheater(id: Int) async throws {}
    func addFavoriteTheater(code: String) async throws -> FavoriteTheater {
        FavoriteTheater(id: 2, code: code, isActive: true, position: 1)
    }

    func logs(page: Int, level: String, search: String) async throws -> PaginatedResult<SystemLog> {
        try await withCheckedThrowingContinuation {
            logsRequests.append(LogsRequest(page: page, level: level, search: search, continuation: $0))
        }
    }

    func clearLogs() async throws {}
}

@main
struct LoadingRegressions {
    @MainActor
    static func waitUntil(_ predicate: () -> Bool) async {
        for _ in 0..<10_000 {
            if predicate() { return }
            await Task.yield()
        }
        fatalError("A replacement request was not started")
    }

    @MainActor
    static func main() async {
        await showtimesLatestDateWins()
        await showtimesStaleFailureIsIgnored()
        await removingLastTheaterInvalidatesPendingLoad()
        await logsFiltersReplacePendingPage()
        await logsStaleFailureIsIgnored()
        await logsRefreshRestartsPagination()
        print("PASS: 6 loading regressions using production view models")
    }

    @MainActor
    static func showtimesLatestDateWins() async {
        let api = APIService.shared
        let offset = api.showtimesRequests.count
        let model = ShowtimesViewModel()
        let first = Task { await model.start() }
        await waitUntil { api.showtimesRequests.count == offset + 1 }
        model.shiftDay(1)
        let second = Task { await model.load() }
        await waitUntil { api.showtimesRequests.count == offset + 2 }
        api.showtimesRequests[offset + 1].succeed()
        await second.value
        let latestDate = api.showtimesRequests[offset + 1].date
        assert(model.programs.first?.date == latestDate)
        api.showtimesRequests[offset].succeed()
        await first.value
        assert(model.programs.first?.date == latestDate)
        assert(!model.isLoading && model.errorMessage == nil)
    }

    @MainActor
    static func showtimesStaleFailureIsIgnored() async {
        let api = APIService.shared
        let offset = api.showtimesRequests.count
        let model = ShowtimesViewModel()
        let first = Task { await model.start() }
        await waitUntil { api.showtimesRequests.count == offset + 1 }
        model.shiftDay(1)
        let second = Task { await model.load() }
        await waitUntil { api.showtimesRequests.count == offset + 2 }
        api.showtimesRequests[offset].continuation.resume(throwing: ProbeError.oldRequestFailed)
        await first.value
        assert(model.isLoading && model.errorMessage == nil)
        api.showtimesRequests[offset + 1].succeed()
        await second.value
        assert(!model.isLoading && model.programs.first?.date == api.showtimesRequests[offset + 1].date)
    }

    @MainActor
    static func removingLastTheaterInvalidatesPendingLoad() async {
        let api = APIService.shared
        let offset = api.showtimesRequests.count
        let model = ShowtimesViewModel()
        let first = Task { await model.start() }
        await waitUntil { api.showtimesRequests.count == offset + 1 }
        await model.removeFavorite(model.favorites[0])
        api.showtimesRequests[offset].succeed()
        await first.value
        assert(model.favorites.isEmpty && model.programs.isEmpty && !model.isLoading)
    }

    @MainActor
    static func logsFiltersReplacePendingPage() async {
        let api = APIService.shared
        let offset = api.logsRequests.count
        let model = LogsViewModel()
        let first = Task { await model.loadInitial() }
        await waitUntil { api.logsRequests.count == offset + 1 }
        model.level = .error
        model.search = "confirmed query"
        let filtered = Task { await model.applyFilters() }
        await waitUntil { api.logsRequests.count == offset + 2 }
        api.logsRequests[offset].succeed(id: 1)
        await first.value
        assert(model.isLoading && model.logs.isEmpty)
        api.logsRequests[offset + 1].succeed(id: 2)
        await filtered.value
        assert(model.logs.map(\.id) == [2] && model.totalCount == 3)

        // Editing the search field must not silently change a subsequent page.
        model.search = "unsubmitted draft"
        let more = Task { await model.loadMore() }
        await waitUntil { api.logsRequests.count == offset + 3 }
        let request = api.logsRequests[offset + 2]
        assert(request.page == 2 && request.level == "Error" && request.search == "confirmed query")
        request.succeed(id: 3)
        await more.value
        assert(model.logs.map(\.id) == [2, 3])
    }

    @MainActor
    static func logsStaleFailureIsIgnored() async {
        let api = APIService.shared
        let offset = api.logsRequests.count
        let model = LogsViewModel()
        let first = Task { await model.loadInitial() }
        await waitUntil { api.logsRequests.count == offset + 1 }
        model.level = .warning
        let filtered = Task { await model.applyFilters() }
        await waitUntil { api.logsRequests.count == offset + 2 }
        api.logsRequests[offset + 1].succeed(id: 4, totalPages: 1)
        await filtered.value
        api.logsRequests[offset].continuation.resume(throwing: ProbeError.oldRequestFailed)
        await first.value
        assert(model.logs.map(\.id) == [4] && model.errorMessage == nil)
        assert(!model.canLoadMore && !model.isLoading)
    }

    @MainActor
    static func logsRefreshRestartsPagination() async {
        let api = APIService.shared
        let offset = api.logsRequests.count
        let model = LogsViewModel()
        let initial = Task { await model.loadInitial() }
        await waitUntil { api.logsRequests.count == offset + 1 }
        api.logsRequests[offset].succeed(id: 5)
        await initial.value
        let more = Task { await model.loadMore() }
        await waitUntil { api.logsRequests.count == offset + 2 }
        let refreshed = Task { await model.refresh() }
        await waitUntil { api.logsRequests.count == offset + 3 }
        assert(model.logs.map(\.id) == [5]) // Keep the scroll view during refresh.
        api.logsRequests[offset + 2].succeed(id: 6)
        await refreshed.value
        api.logsRequests[offset + 1].succeed(id: 7)
        await more.value
        assert(model.logs.map(\.id) == [6])
        let next = Task { await model.loadMore() }
        await waitUntil { api.logsRequests.count == offset + 4 }
        assert(api.logsRequests[offset + 3].page == 2)
        api.logsRequests[offset + 3].succeed(id: 8)
        await next.value
        assert(model.logs.map(\.id) == [6, 8])
    }
}
