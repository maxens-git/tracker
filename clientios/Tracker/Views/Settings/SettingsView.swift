//
//  SettingsView.swift
//  Tracker
//
//  Écran de réglages de l'application.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
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
    @State private var statusMessage: String?

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
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

                Section("À propos") {
                    LabeledContent("Version", value: appVersion)
                }
            }
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
        .task { await loadRemoteSettings() }
        // La feuille a son propre contexte de présentation et n'hérite pas du
        // preferredColorScheme appliqué à la racine : on le réapplique ici pour
        // que le changement de thème soit visible immédiatement dans cet écran.
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
