//
//  NotificationSyncService.swift
//  Tracker
//
//  Orchestration de la découverte TMDB et des requêtes locales.
//

import Foundation

@MainActor
final class NotificationSyncService {
    static let shared = NotificationSyncService()

    private let api = APIService.shared
    private let discovery = ReleaseDiscoveryService.shared
    private let notifications = LocalNotificationService.shared

    private init() {}

    @discardableResult
    func sync(settings suppliedSettings: AppSettingsDTO? = nil, forceRefresh: Bool = false) async throws -> Int {
        guard NotificationPreferences.delivery == .tracker else { return 0 }

        let settings: AppSettingsDTO
        if let suppliedSettings {
            settings = suppliedSettings
        } else {
            settings = try await api.settings(forceRefresh: forceRefresh)
        }
        AppConfig.setTmdbOverrides(
            apiKey: settings.tmdbApiKey,
            baseURL: settings.tmdbBaseUrl,
            language: settings.tmdbLanguage)

        let result = try await discovery.discover(forceRefresh: forceRefresh)
        return try await notifications.schedule(
            items: result.items,
            daysAhead: settings.notifyDaysAhead,
            hour: settings.notificationHour,
            minute: settings.notificationMinute)
    }
}
