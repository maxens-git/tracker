//
//  SettingsView.swift
//  Tracker
//
//  Écran de réglages de l'application.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @AppStorage(AppStorageKeys.theme) private var theme: AppTheme = .system
    @AppStorage(AppStorageKeys.hideSeenItems) private var hideSeenItems = false
    @State private var ntfyEnabled = false
    @State private var ntfyUrl = ""
    @State private var ntfyTopic = ""
    @State private var ntfyToken = ""
    @State private var notifyDaysAhead = 1
    @State private var notificationTime = Self.makeNotificationTime(hour: 9, minute: 0)
    @State private var isLoadingSettings = false
    @State private var isSavingSettings = false
    @State private var isSubscribingCalendar = false
    @State private var statusMessage: String?
    @State private var calendarMessage: String?

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }

    var body: some View {
        Form {
            Section("Apparence") {
                Picker("Thème", selection: $theme) {
                    ForEach(AppTheme.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                Toggle("Masquer les médias déjà vus", isOn: $hideSeenItems)
            } header: {
                Text("Accueil")
            } footer: {
                Text("Les films et séries marqués comme vus n'apparaîtront plus sur la page d'accueil.")
            }

            Section {
                Toggle("Activer ntfy", isOn: $ntfyEnabled)
                TextField("https://ntfy.sh", text: $ntfyUrl)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Topic", text: $ntfyTopic)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Token", text: $ntfyToken)
                Stepper("Prévenir \(notifyDaysAhead) jour\(notifyDaysAhead > 1 ? "s" : "") avant",
                        value: $notifyDaysAhead, in: 0...30)
                DatePicker("Heure d’envoi", selection: $notificationTime, displayedComponents: .hourAndMinute)

                Button {
                    Task { await saveRemoteSettings() }
                } label: {
                    if isSavingSettings {
                        ProgressView()
                    } else {
                        Text("Enregistrer")
                    }
                }
                .disabled(isSavingSettings || isLoadingSettings)
            } header: {
                Text("Notifications")
            } footer: {
                Text(statusMessage ?? "Les sorties suivies peuvent déclencher une notification via ntfy.")
            }

            Section {
                Button {
                    Task { await subscribeToCalendar() }
                } label: {
                    HStack {
                        Label("S'abonner au calendrier", systemImage: "calendar.badge.plus")
                        Spacer()
                        if isSubscribingCalendar { ProgressView() }
                    }
                }
                .disabled(isSubscribingCalendar)
            } header: {
                Text("Calendrier")
            } footer: {
                Text(calendarMessage ?? "Ajoute les sorties suivies à ton calendrier. Les ajouts et suppressions se synchronisent automatiquement.")
            }

            Section("À propos") {
                LabeledContent("Version", value: appVersion)
            }
        }
        .navigationTitle("Réglages")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground.ignoresSafeArea())
        .task { await loadRemoteSettings() }
        // Réappliqué ici pour que le changement de thème soit visible
        // immédiatement dans cet écran, sans attendre un retour à la racine.
        .preferredColorScheme(theme.colorScheme)
    }

    private func loadRemoteSettings() async {
        guard !isLoadingSettings else { return }
        isLoadingSettings = true
        defer { isLoadingSettings = false }
        do {
            let settings = try await APIService.shared.settings(forceRefresh: true)
            ntfyEnabled = settings.ntfyEnabled
            ntfyUrl = settings.ntfyUrl ?? ""
            ntfyTopic = settings.ntfyTopic ?? ""
            ntfyToken = settings.ntfyToken ?? ""
            notifyDaysAhead = settings.notifyDaysAhead
            notificationTime = Self.makeNotificationTime(hour: settings.notificationHour, minute: settings.notificationMinute)
        } catch {
            if !error.isCancellation { statusMessage = error.localizedDescription }
        }
    }

    private func saveRemoteSettings() async {
        guard !isSavingSettings else { return }
        isSavingSettings = true
        defer { isSavingSettings = false }
        do {
            let components = Calendar.current.dateComponents([.hour, .minute], from: notificationTime)
            _ = try await APIService.shared.updateSettings(AppSettingsDTO(
                ntfyEnabled: ntfyEnabled,
                ntfyUrl: ntfyUrl.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                ntfyTopic: ntfyTopic.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                ntfyToken: ntfyToken.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                notifyDaysAhead: notifyDaysAhead,
                notificationHour: components.hour ?? 9,
                notificationMinute: components.minute ?? 0,
                updatedAt: nil))
            statusMessage = "Réglages enregistrés."
            Haptics.success()
        } catch {
            if !error.isCancellation { statusMessage = error.localizedDescription }
            Haptics.error()
        }
    }

    /// Récupère l'URL d'abonnement auprès du backend puis l'ouvre en `webcal://`,
    /// ce qui propose l'ajout du calendrier dans l'app Calendrier d'iOS.
    private func subscribeToCalendar() async {
        guard !isSubscribingCalendar else { return }
        isSubscribingCalendar = true
        defer { isSubscribingCalendar = false }
        do {
            let info = try await APIService.shared.calendarInfo(forceRefresh: true)
            guard let url = URL(string: info.webcalUrl) else {
                calendarMessage = "URL de calendrier invalide."
                return
            }
            openURL(url)
            Haptics.success()
        } catch {
            if !error.isCancellation { calendarMessage = error.localizedDescription }
            Haptics.error()
        }
    }

    private static func makeNotificationTime(hour: Int, minute: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = min(max(hour, 0), 23)
        components.minute = min(max(minute, 0), 59)
        return Calendar.current.date(from: components) ?? Date()
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

#Preview {
    SettingsView()
}
