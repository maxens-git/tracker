//
//  SettingsView.swift
//  Tracker
//
//  Écran de réglages de l'application.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @AppStorage(AppStorageKeys.hideSeenItems) private var hideSeenItems = false
    @AppStorage(AppStorageKeys.useDevServer) private var useDevServer = false
    @State private var ntfyEnabled = false
    @State private var ntfyUrl = ""
    @State private var ntfyTopic = ""
    @State private var ntfyToken = ""
    @State private var notifyDaysAhead = 1
    @State private var notificationTime = Self.makeNotificationTime(hour: 9, minute: 0)
    @AppStorage(AppStorageKeys.torrentsEnabled) private var torrentsEnabled = true
    @State private var prowlarrUrl = ""
    @State private var prowlarrApiKey = ""
    @State private var allDebridApiKey = ""
    @State private var tmdbApiKey = ""
    @State private var tmdbBaseUrl = ""
    @State private var tmdbLanguage = ""
    @State private var isLoadingSettings = false
    @State private var isSavingSettings = false
    @State private var isSubscribingCalendar = false
    @State private var statusMessage: String?
    @State private var calendarMessage: String?
    @State private var cacheSize = 0

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }

    /// Date de build déduite de la date de modification de l'exécutable de l'app.
    private var buildDate: String {
        guard let url = Bundle.main.executableURL,
              let date = try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date else {
            return "—"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter.string(from: date)
    }

    var body: some View {
        Form {
            Section {
                Picker("Serveur", selection: $useDevServer) {
                    Text("Production").tag(false)
                    Text("Dev (localhost)").tag(true)
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Serveur")
            }

            Section {
                Toggle("Masquer les médias déjà vus", isOn: $hideSeenItems)
            } header: {
                Text("Accueil")
            } footer: {
                Text("Les films et séries marqués comme vus n'apparaîtront plus sur la page d'accueil.")
            }

            Section {
                Toggle("Activer NTFY", isOn: $ntfyEnabled)
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
                Toggle("Activer la recherche & le débridage", isOn: $torrentsEnabled)
                TextField("http://localhost:9696", text: $prowlarrUrl)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Clé API Prowlarr", text: $prowlarrApiKey)
                SecureField("Clé API AllDebrid", text: $allDebridApiKey)

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
                Text("Recherche & débridage")
            } footer: {
                Text("Rechercher des torrents via Prowlarr et récupérer un lien direct via AllDebrid. Désactivé, l’onglet Torrents est masqué.")
            }

            Section {
                SecureField("Clé API TMDB", text: $tmdbApiKey)
                TextField("https://api.themoviedb.org/3", text: $tmdbBaseUrl)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("fr-FR", text: $tmdbLanguage)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

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
                Text("TMDB")
            } footer: {
                Text("Clé, URL et langue utilisées pour interroger l’API TMDB. Laisser vide pour garder les valeurs par défaut.")
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
                Text(calendarMessage ?? "Ajoute les sorties suivies au calendrier.")
            }

            Section {
                LabeledContent("Espace utilisé", value: CacheManager.formatted(cacheSize))
                Button(role: .destructive) {
                    CacheManager.clear()
                    cacheSize = CacheManager.diskUsage
                    Haptics.success()
                } label: {
                    Label("Vider le cache", systemImage: "trash")
                }
                .disabled(cacheSize == 0)
            } header: {
                Text("Cache")
            } footer: {
                Text("Les affiches et fiches TMDB sont conservées pour un affichage plus rapide et hors-ligne. Vider le cache les retéléchargera au besoin.")
            }

            Section("À propos") {
                LabeledContent("Version", value: appVersion)
                LabeledContent("Date de build", value: buildDate)
            }
        }
        .navigationTitle("Réglages")
        .onAppear { cacheSize = CacheManager.diskUsage }
        .task { await loadRemoteSettings() }
        // Rechargement des réglages distants après une bascule de serveur.
        .onChange(of: useDevServer) { Task { await loadRemoteSettings() } }
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
            torrentsEnabled = settings.torrentsEnabled
            prowlarrUrl = settings.prowlarrUrl ?? ""
            prowlarrApiKey = settings.prowlarrApiKey ?? ""
            allDebridApiKey = settings.allDebridApiKey ?? ""
            tmdbApiKey = settings.tmdbApiKey ?? ""
            tmdbBaseUrl = settings.tmdbBaseUrl ?? ""
            tmdbLanguage = settings.tmdbLanguage ?? ""
            AppConfig.setTmdbOverrides(apiKey: settings.tmdbApiKey, baseURL: settings.tmdbBaseUrl, language: settings.tmdbLanguage)
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
                torrentsEnabled: torrentsEnabled,
                prowlarrUrl: prowlarrUrl.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                prowlarrApiKey: prowlarrApiKey.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                allDebridApiKey: allDebridApiKey.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                tmdbApiKey: tmdbApiKey.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                tmdbBaseUrl: tmdbBaseUrl.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                tmdbLanguage: tmdbLanguage.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                updatedAt: nil))
            AppConfig.setTmdbOverrides(apiKey: tmdbApiKey, baseURL: tmdbBaseUrl, language: tmdbLanguage)
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
