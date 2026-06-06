//
//  StatsView.swift
//  Tracker
//

import SwiftUI
import Charts

struct StatsView: View {
    @State private var viewModel = StatsViewModel()

    var body: some View {
        ScrollView {
            if let stats = viewModel.stats {
                VStack(spacing: 24) {
                    summaryGrid(stats)
                    if !stats.moviesSeenByYear.isEmpty {
                        chart("Films vus par année", data: stats.moviesSeenByYear)
                    }
                    if !stats.showsSeenByYear.isEmpty {
                        chart("Séries vues par année", data: stats.showsSeenByYear)
                    }
                }
                .padding()
            } else if viewModel.isLoading {
                // Contenu minimal : on remplit l'écran pour que le fond reste uniforme
                // pendant le chargement (sinon une bande au mauvais fond apparaît).
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 400)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Statistiques")
        .overlay {
            if let error = viewModel.errorMessage, viewModel.stats == nil {
                ContentUnavailableView("Erreur", systemImage: "chart.bar", description: Text(error))
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    private func summaryGrid(_ stats: Stats) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            statCard("Films vus", value: "\(stats.moviesSeenCount)", systemImage: "film")
            statCard("Séries vues", value: "\(stats.showsSeenCount)", systemImage: "tv")
            statCard("Épisodes vus", value: "\(stats.episodesSeenCount)", systemImage: "play.rectangle")
            statCard("Temps total", value: "\(Int(stats.totalRuntimeHours)) h", systemImage: "clock")
        }
    }

    private func statCard(_ title: String, value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.tint)
            Text(value).font(.title.bold())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
    }

    private func chart(_ title: String, data: [StatsYearBucket]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title3.bold())
            Chart(data) { bucket in
                BarMark(
                    x: .value("Année", String(bucket.year)),
                    y: .value("Nombre", bucket.count)
                )
                .foregroundStyle(Color.accentColor)
            }
            .frame(height: 200)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
    }
}

#Preview {
    NavigationStack { StatsView() }
}
