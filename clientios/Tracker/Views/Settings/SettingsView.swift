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
        // La feuille a son propre contexte de présentation et n'hérite pas du
        // preferredColorScheme appliqué à la racine : on le réapplique ici pour
        // que le changement de thème soit visible immédiatement dans cet écran.
        .preferredColorScheme(theme.colorScheme)
    }
}

#Preview {
    SettingsView()
}
