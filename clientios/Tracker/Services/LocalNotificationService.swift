//
//  LocalNotificationService.swift
//  Tracker
//
//  Programmation des alertes de sorties directement par iOS. Une requête est
//  créée par film, saison et épisode daté ; iOS assure ensuite la livraison,
//  même lorsque Tracker n'est plus lancé.
//

import Foundation
import UserNotifications

enum LocalNotificationError: LocalizedError {
    case permissionRequired

    var errorDescription: String? {
        switch self {
        case .permissionRequired:
            "Les notifications Tracker ne sont pas autorisées dans les réglages iOS."
        }
    }
}

@MainActor
final class LocalNotificationService {
    static let shared = LocalNotificationService()

    private let center = UNUserNotificationCenter.current()
    private let releasePrefix = "tracker.release."
    private let testIdentifier = "tracker.test"

    private init() {}

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Reconstruit toutes les alertes Tracker. Le retrait préalable des anciennes
    /// requêtes évite de conserver une date périmée après une modification TMDB.
    @discardableResult
    func schedule(
        items: [ReleaseCalendarItem],
        daysAhead: Int,
        hour: Int,
        minute: Int
    ) async throws -> Int {
        guard await canSchedule else { throw LocalNotificationError.permissionRequired }

        await cancelAllReleases()

        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let clampedDays = min(max(daysAhead, 0), 30)
        let clampedHour = min(max(hour, 0), 23)
        let clampedMinute = min(max(minute, 0), 59)

        let candidates = items.compactMap { item -> ScheduledRelease? in
            guard !item.pending,
                  let releaseDay = DateOnlyFormatter.date(from: item.date),
                  releaseDay >= today,
                  let alertDay = calendar.date(byAdding: .day, value: -clampedDays, to: releaseDay) else {
                return nil
            }

            var alertComponents = calendar.dateComponents([.year, .month, .day], from: alertDay)
            alertComponents.hour = clampedHour
            alertComponents.minute = clampedMinute
            alertComponents.second = 0
            guard let alertDate = calendar.date(from: alertComponents), alertDate > now else {
                // Une alerte dont l'heure est déjà passée n'est pas rejouée à
                // chaque lancement : elle sera simplement recréée au prochain événement.
                return nil
            }
            return ScheduledRelease(item: item, alertDate: alertDate)
        }
        .sorted { $0.alertDate < $1.alertDate }
        .prefix(64)

        var scheduledCount = 0
        for candidate in candidates {
            let content = notificationContent(for: candidate.item)
            var triggerComponents = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: candidate.alertDate)
            triggerComponents.calendar = calendar
            triggerComponents.timeZone = calendar.timeZone

            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
            let request = UNNotificationRequest(
                identifier: releasePrefix + candidate.item.id,
                content: content,
                trigger: trigger)
            try await center.add(request)
            scheduledCount += 1
        }
        return scheduledCount
    }

    func sendTestNotification() async throws {
        guard await canSchedule else { throw LocalNotificationError.permissionRequired }

        center.removePendingNotificationRequests(withIdentifiers: [testIdentifier])
        let content = UNMutableNotificationContent()
        content.title = "Test Tracker"
        content.body = "Les notifications locales sont correctement configurées."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        try await center.add(UNNotificationRequest(
            identifier: testIdentifier,
            content: content,
            trigger: trigger))
    }

    func cancelAllReleases() async {
        let identifiers = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(releasePrefix) }
        if !identifiers.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }

    func cancel(tmdbId: Int, type: MediaType) async {
        let identifiers = await center.pendingNotificationRequests().compactMap { request -> String? in
            guard request.identifier.hasPrefix(releasePrefix),
                  request.content.userInfo["tmdbId"] as? Int == tmdbId,
                  request.content.userInfo["mediaType"] as? String == type.rawValue else {
                return nil
            }
            return request.identifier
        }
        if !identifiers.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }

    private var canSchedule: Bool {
        get async {
            switch await authorizationStatus() {
            case .authorized, .provisional, .ephemeral:
                true
            default:
                false
            }
        }
    }

    private func notificationContent(for item: ReleaseCalendarItem) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        switch item.kind {
        case "Épisode":
            content.title = "Nouvel épisode · \(item.title)"
        case "Saison":
            content.title = "Nouvelle saison · \(item.title)"
        default:
            content.title = "Sortie · \(item.title)"
        }
        content.body = "\(item.subtitle) · \(DateOnlyFormatter.display(item.date))"
        content.sound = .default
        content.threadIdentifier = "\(item.type.rawValue)-\(item.tmdbId)"
        content.userInfo = [
            "tmdbId": item.tmdbId,
            "mediaType": item.type.rawValue,
            "releaseId": item.id,
        ]
        return content
    }
}

private struct ScheduledRelease {
    let item: ReleaseCalendarItem
    let alertDate: Date
}
