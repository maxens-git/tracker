//
//  MoreView.swift
//  Tracker
//
//  Onglet « Plus » : regroupe les destinations secondaires (Activité, Stats)
//  et les réglages, dans le même vocabulaire visuel « cinéma » que le reste
//  de l'app (fond chaud + cartes). Évite la page « More » système d'iOS qui
//  apparaîtrait au-delà de 5 onglets et ne suit pas le thème.
//

import SwiftUI

struct MoreView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                row(icon: "clock.arrow.circlepath", title: "Activité",
                    subtitle: "Vos dernières actions") { ActivityView() }

                row(icon: "chart.bar", title: "Stats",
                    subtitle: "Votre suivi en chiffres") { StatsView() }

                row(icon: "gearshape", title: "Réglages",
                    subtitle: "Thème, accueil, notifications") { SettingsView() }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .navigationTitle("Plus")
        .background(Color.appBackground.ignoresSafeArea())
    }

    private func row<Destination: View>(
        icon: String,
        title: String,
        subtitle: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            MoreRow(icon: icon, title: title, subtitle: subtitle)
        }
        .buttonStyle(.plain)
    }
}

private struct MoreRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .cinemaCard()
    }
}

#Preview {
    NavigationStack { MoreView() }
}
