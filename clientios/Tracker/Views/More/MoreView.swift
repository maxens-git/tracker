//
//  MoreView.swift
//  Tracker
//
//  Onglet « Plus » : liste groupée de destinations secondaires, sur le modèle
//  des Réglages d'iOS (icône colorée, libellé, chevron automatique).
//

import SwiftUI

struct MoreView: View {
    // Piloté par les réglages : masque l'entrée Torrents quand la recherche
    // & le débridage sont désactivés. Persisté pour éviter un clignotement au
    // lancement, puis rafraîchi depuis le serveur à l'apparition de l'écran.
    @AppStorage(AppStorageKeys.torrentsEnabled) private var torrentsEnabled = true

    var body: some View {
        List {
            Section {
                row(icon: "ticket.fill", tint: .orange, title: "Séances",
                    subtitle: "Cinémas & horaires") { ShowtimesView() }

                if torrentsEnabled {
                    row(icon: "arrow.down.circle.fill", tint: .teal, title: "Torrents",
                        subtitle: "Recherche & débridage") { TorrentsView() }
                }

                row(icon: "clock.arrow.circlepath", tint: .indigo, title: "Activité",
                    subtitle: "Vos dernières actions") { ActivityView() }

                row(icon: "chart.bar.fill", tint: .green, title: "Stats",
                    subtitle: "Votre suivi en chiffres") { StatsView() }
            }

            Section {
                row(icon: "gearshape.fill", tint: .gray, title: "Réglages",
                    subtitle: "Serveur, accueil, notifications") { SettingsView() }

                row(icon: "doc.text.magnifyingglass", tint: .gray, title: "Logs",
                    subtitle: "Journal système") { LogsView() }
            }
        }
        .navigationTitle("Plus")
        .task {
            if let settings = try? await APIService.shared.settings() {
                torrentsEnabled = settings.torrentsEnabled
            }
        }
    }

    private func row<Destination: View>(
        icon: String,
        tint: Color,
        title: String,
        subtitle: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                // Icône en pastille colorée, comme dans les Réglages d'iOS.
                Image(systemName: icon)
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .frame(width: 29, height: 29)
                    .background(tint, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
        }
    }
}

#Preview {
    NavigationStack { MoreView() }
}
