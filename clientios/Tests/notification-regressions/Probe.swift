import Foundation

enum ProbeError: Error { case offline }
enum NotificationDelivery { case disabled, tracker }
enum NotificationPreferences { static var delivery = NotificationDelivery.tracker }
enum AppConfig {
    static func setTmdbOverrides(apiKey: String?, baseURL: String?, language: String?) {}
}

final class APIService {
    static let shared = APIService()
    var tracked: [TrackedMedia] = []

    func trackedMedia(forceRefresh: Bool) async throws -> [TrackedMedia] { tracked }
    func settings(forceRefresh: Bool) async throws -> AppSettingsDTO {
        AppSettingsDTO(
            ntfyEnabled: false, ntfyUrl: nil, ntfyTopic: nil, ntfyToken: nil,
            notifyDaysAhead: 1, notificationHour: 9, notificationMinute: 0,
            torrentsEnabled: false, prowlarrUrl: nil, prowlarrApiKey: nil,
            allDebridApiKey: nil, tmdbApiKey: nil, tmdbBaseUrl: nil,
            tmdbLanguage: nil, updatedAt: nil)
    }
}

final class TMDBService {
    static let shared = TMDBService()
    enum Failure { case none, movie, show, season }
    var failure = Failure.none
    var cancelOnMovie = false
    var disableOnMovie = false

    func movie(_ id: Int, forceRefresh: Bool) async throws -> TMDBMovie {
        if failure == .movie { throw ProbeError.offline }
        if cancelOnMovie { withUnsafeCurrentTask { $0?.cancel() } }
        if disableOnMovie { NotificationPreferences.delivery = .disabled }
        return try JSONDecoder().decode(TMDBMovie.self, from: Data("""
            {"id":\(id),"title":"Movie","release_date":"2099-12-31"}
            """.utf8))
    }

    func show(_ id: Int, forceRefresh: Bool) async throws -> TMDBShow {
        if failure == .show { throw ProbeError.offline }
        return try JSONDecoder().decode(TMDBShow.self, from: Data("""
            {"id":\(id),"name":"Show","seasons":[
              {"id":1,"season_number":1,"name":"Season 1","episode_count":1,"air_date":"2099-12-31"}
            ]}
            """.utf8))
    }

    func season(showId: Int, seasonNumber: Int) async throws -> TMDBSeasonDetail {
        if failure == .season { throw ProbeError.offline }
        return try JSONDecoder().decode(TMDBSeasonDetail.self, from: Data("""
            {"id":1,"season_number":1,"name":"Season 1","episodes":[
              {"id":1,"season_number":1,"episode_number":1,"name":"Episode 1","air_date":"2099-12-31"}
            ]}
            """.utf8))
    }
}

final class LocalNotificationService {
    static let shared = LocalNotificationService()
    var scheduledIDs = ["existing-reminder"]
    var scheduleCalls = 0
    func schedule(items: [ReleaseCalendarItem], daysAhead: Int, hour: Int, minute: Int) async throws -> Int {
        scheduleCalls += 1
        scheduledIDs = items.map(\.id)
        return items.count
    }
}

@main struct NotificationRegressionTests {
    static func tracked(_ type: MediaType) -> TrackedMedia {
        TrackedMedia(id: type == .movie ? 1 : 2, tmdbId: 7, mediaType: type.rawValue,
                     title: "Fixture", posterPath: nil, addedAt: nil)
    }

    static func main() async throws {
        let api = APIService.shared
        let tmdb = TMDBService.shared
        let notifications = LocalNotificationService.shared
        let sync = NotificationSyncService.shared

        // A failed movie, show, or season must never hand partial data to the scheduler.
        for failure in [TMDBService.Failure.movie, .show, .season] {
            api.tracked = [tracked(.movie), tracked(.tv)]
            tmdb.failure = failure
            do {
                try await sync.sync()
                fatalError("Incomplete discovery must fail")
            } catch ProbeError.offline {}
            precondition(notifications.scheduleCalls == 0)
            precondition(notifications.scheduledIDs == ["existing-reminder"])
        }
        print("PASS: movie/show/season failures preserve existing reminders")

        tmdb.failure = .none
        let count = try await sync.sync()
        precondition(count == 3 && notifications.scheduleCalls == 1)
        print("PASS: complete discovery schedules film, season and episode")

        // An authoritative empty tracking list still removes obsolete reminders.
        api.tracked = []
        _ = try await sync.sync()
        precondition(notifications.scheduledIDs.isEmpty && notifications.scheduleCalls == 2)
        print("PASS: successful empty discovery removes obsolete reminders")

        api.tracked = [tracked(.movie)]
        tmdb.cancelOnMovie = true
        let cancelled = Task { try await sync.sync() }
        do {
            _ = try await cancelled.value
            fatalError("Cancelled discovery must fail")
        } catch is CancellationError {}
        precondition(notifications.scheduleCalls == 2)
        print("PASS: cancelled discovery does not replace reminders")

        tmdb.cancelOnMovie = false
        tmdb.disableOnMovie = true
        _ = try await sync.sync()
        precondition(notifications.scheduleCalls == 2)
        print("PASS: disabling notifications during discovery prevents rescheduling")
    }
}
