//
//  ReleaseCalendarViewModel.swift
//  Tracker
//

import Foundation

struct ReleaseCalendarItem: Identifiable, Hashable {
    let id: String
    let tmdbId: Int
    let type: MediaType
    let kind: String
    let title: String
    let subtitle: String
    let date: String
    let posterPath: String?
    /// Annoncé sur TMDB sans date publiée : affiché hors calendrier, dans la section « à venir ».
    var pending: Bool = false
}

@Observable
@MainActor
final class ReleaseCalendarViewModel {
    private let api = APIService.shared
    private let discovery = ReleaseDiscoveryService.shared

    private(set) var items: [ReleaseCalendarItem] = []
    /// Saisons/films annoncés sans date confirmée sur TMDB (ex. série « terminée » avec une saison à venir).
    private(set) var pendingItems: [ReleaseCalendarItem] = []
    private(set) var trackedCount = 0
    private(set) var isLoading = false
    var errorMessage: String?

    func load(forceRefresh: Bool = false) async {
        isLoading = true
        errorMessage = nil
        do {
            let discoveryResult = try await discovery.discover(forceRefresh: forceRefresh)
            trackedCount = discoveryResult.trackedCount
            let result = discoveryResult.items
            // Les items datés alimentent le calendrier/la liste ; ceux « à confirmer » leur section dédiée.
            items = result.filter { !$0.pending }.sorted { $0.date < $1.date }
            pendingItems = result.filter { $0.pending }

            // Une consultation/actualisation du calendrier maintient également
            // les requêtes locales à jour, sans second parcours TMDB.
            if NotificationPreferences.delivery == .tracker,
               let settings = try? await api.settings() {
                _ = try? await LocalNotificationService.shared.schedule(
                    items: result,
                    daysAhead: settings.notifyDaysAhead,
                    hour: settings.notificationHour,
                    minute: settings.notificationMinute)
            }
        } catch {
            if !error.isCancellation { errorMessage = error.localizedDescription }
        }
        isLoading = false
    }

    func remove(_ item: ReleaseCalendarItem) async {
        do {
            try await api.removeTrackedMedia(tmdbId: item.tmdbId, type: item.type)
            if NotificationPreferences.delivery == .tracker {
                await LocalNotificationService.shared.cancel(tmdbId: item.tmdbId, type: item.type)
            }
            items.removeAll { $0.tmdbId == item.tmdbId && $0.type == item.type }
            pendingItems.removeAll { $0.tmdbId == item.tmdbId && $0.type == item.type }
            trackedCount = max(0, trackedCount - 1)
            Haptics.impact(.light)
        } catch {
            if !error.isCancellation { errorMessage = error.localizedDescription }
            Haptics.error()
        }
    }

}

enum DateOnlyFormatter {
    static let input: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let output: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .medium
        return formatter
    }()

    static func date(from value: String) -> Date? { input.date(from: value) }
    static func display(_ value: String) -> String {
        guard let date = date(from: value) else { return value }
        return output.string(from: date)
    }
}
