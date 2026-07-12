//
//  StatsView.swift
//  Tracker
//

import SwiftUI
import Charts

struct StatsView: View {
    @State private var viewModel = StatsViewModel()

    // Couleurs des catégories (alignées avec la légende).
    private let movieColor = Color.appGold
    private let episodeColor = Color.appGreen

    var body: some View {
        ScrollView {
            if let stats = viewModel.stats {
                VStack(spacing: 24) {
                    summaryGrid(stats)

                    if !viewModel.genreLists.isEmpty {
                        GenrePreferenceCard(lists: viewModel.genreLists,
                                            selectedListId: $viewModel.selectedListId,
                                            genres: viewModel.selectedGenres)
                    }

                    if !viewModel.byYear.isEmpty {
                        ActivityChart(title: "Activité par année",
                                      bars: viewModel.byYear.map {
                                          .init(label: String($0.year), movies: $0.movies, episodes: $0.episodes)
                                      },
                                      movieColor: movieColor, episodeColor: episodeColor)
                    }

                    ActivityChart(title: "12 derniers mois",
                                  bars: viewModel.byMonth.map {
                                      .init(label: $0.label, movies: $0.movies, episodes: $0.episodes)
                                  },
                                  movieColor: movieColor, episodeColor: episodeColor)
                }
                .padding()
            } else if viewModel.isLoading {
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
            statCard("Temps total", value: viewModel.formatRuntime(stats.totalRuntimeMinutes), systemImage: "clock")
        }
    }

    private func statCard(_ title: String, value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.tint)
            Text(value).font(.display(28))
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .cinemaCard()
    }
}

// MARK: - Genres préférés

/// Mode de calcul des pourcentages de genres.
/// `.titles` = % de titres ayant ce genre (somme > 100 %) ;
/// `.tags` = part de chaque genre (somme = 100 %).
private enum GenreMode: Hashable {
    case titles, tags
}

private struct GenrePreferenceCard: View {
    let lists: [StatsListGenres]
    @Binding var selectedListId: Int?
    let genres: [StatsGenreBucket]

    private static let collapsedCount = 7
    @State private var showAll = false
    @State private var mode: GenreMode = .titles

    private let colors: [Color] = [
        Color(hex: 0xE89A63),
        Color(hex: 0x8BA7EA),
        Color(hex: 0x51B7D3),
        Color(hex: 0xA7BA63),
        Color(hex: 0x64BD8D),
        Color(hex: 0xEA8E94),
        Color(hex: 0xDD83AE),
    ]

    /// Genres avec le % recalculé selon le mode choisi.
    private var scoredGenres: [StatsGenreBucket] {
        guard mode == .tags else { return genres }
        let total = genres.reduce(0) { $0 + $1.count }
        guard total > 0 else { return genres }
        return genres.map {
            StatsGenreBucket(name: $0.name, count: $0.count,
                             percentage: Int((Double($0.count) * 100 / Double(total)).rounded()))
        }
    }

    private var selectedList: StatsListGenres? {
        lists.first { $0.listId == selectedListId }
    }

    private var maxPercentage: Int {
        max(scoredGenres.map(\.percentage).max() ?? 1, 1)
    }

    private var visibleGenres: [StatsGenreBucket] {
        showAll ? scoredGenres : Array(scoredGenres.prefix(Self.collapsedCount))
    }

    private var hasMore: Bool {
        scoredGenres.count > Self.collapsedCount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionHeader("Genres préférés")

            if lists.count > 1 {
                listDropdown
            }

            Picker("Mode", selection: $mode) {
                Text("Par titre").tag(GenreMode.titles)
                Text("Répartition").tag(GenreMode.tags)
            }
            .pickerStyle(.segmented)

            VStack(spacing: 20) {
                ForEach(Array(visibleGenres.enumerated()), id: \.element.id) { index, genre in
                    genreRow(genre, color: colors[index % colors.count])
                }
            }

            if hasMore {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showAll.toggle() }
                } label: {
                    Text(showAll ? "Voir moins" : "Voir plus")
                        .font(.display(15, .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .cinemaCard()
        .onChange(of: selectedListId) { showAll = false }
    }

    /// Dropdown de sélection de liste (menu natif iOS).
    private var listDropdown: some View {
        Menu {
            Picker("Liste", selection: $selectedListId) {
                ForEach(lists) { list in
                    Text(menuLabel(list)).tag(list.listId as Int?)
                }
            }
        } label: {
            HStack(spacing: 6) {
                if let icon = selectedList?.icon, !icon.isEmpty {
                    Text(icon)
                }
                Text(selectedList?.name ?? "Liste")
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.appSurface, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.appStroke, lineWidth: 1))
        }
    }

    /// Libellé d'un élément du menu : icône + nom.
    private func menuLabel(_ list: StatsListGenres) -> String {
        if let icon = list.icon, !icon.isEmpty { return "\(icon) \(list.name)" }
        return list.name
    }

    private func genreRow(_ genre: StatsGenreBucket, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(genre.name)
                    .font(.display(17, .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer()
                Text("\(genre.percentage)%")
                    .font(.display(17, .semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(color)
                        .frame(width: proxy.size.width * CGFloat(genre.percentage) / CGFloat(maxPercentage))
                }
            }
            .frame(height: 10)
        }
    }
}

// MARK: - Graphique d'activité (barres empilées films / épisodes)

private struct ActivityChart: View {
    struct Bar: Identifiable {
        let label: String
        let movies: Int
        let episodes: Int
        var total: Int { movies + episodes }
        var id: String { label }
    }

    let title: String
    let bars: [Bar]
    let movieColor: Color
    let episodeColor: Color

    /// Barre actuellement sélectionnée par l'utilisateur (toucher / glissement).
    @State private var selectedLabel: String?

    private var selectedBar: Bar? {
        guard let selectedLabel else { return nil }
        return bars.first { $0.label == selectedLabel }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(title)
                Spacer()
                if let bar = selectedBar {
                    Text("\(bar.label) · \(bar.total)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            chart

            legend
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .cinemaCard()
    }

    private var chart: some View {
        Chart(bars) { bar in
            BarMark(
                x: .value("Période", bar.label),
                y: .value("Films", bar.movies)
            )
            .foregroundStyle(movieColor)
            .position(by: .value("Catégorie", "Films"), axis: .vertical)
            .opacity(selectedLabel == nil || selectedLabel == bar.label ? 1 : 0.35)

            BarMark(
                x: .value("Période", bar.label),
                y: .value("Épisodes", bar.episodes)
            )
            .foregroundStyle(episodeColor)
            .position(by: .value("Catégorie", "Épisodes"), axis: .vertical)
            .opacity(selectedLabel == nil || selectedLabel == bar.label ? 1 : 0.35)
        }
        .chartLegend(.hidden)
        .chartXSelection(value: $selectedLabel)
        .chartOverlay { proxy in
            if let bar = selectedBar {
                tooltipOverlay(for: bar, proxy: proxy)
            }
        }
        .frame(height: 220)
    }

    /// Bulle d'information positionnée au-dessus de la barre sélectionnée.
    @ViewBuilder
    private func tooltipOverlay(for bar: Bar, proxy: ChartProxy) -> some View {
        GeometryReader { geo in
            if let plotFrame = proxy.plotFrame,
               let xPosition = proxy.position(forX: bar.label) {
                let origin = geo[plotFrame].origin
                VStack(alignment: .leading, spacing: 4) {
                    Text(bar.label).font(.caption.bold())
                    if bar.movies > 0 {
                        tooltipRow(color: movieColor, text: "\(bar.movies) film\(bar.movies > 1 ? "s" : "")")
                    }
                    if bar.episodes > 0 {
                        tooltipRow(color: episodeColor, text: "\(bar.episodes) épisode\(bar.episodes > 1 ? "s" : "")")
                    }
                    Text("\(bar.total) total")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(radius: 4)
                .fixedSize()
                .position(x: origin.x + xPosition, y: 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func tooltipRow(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text).font(.caption)
        }
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(color: movieColor, label: "Films")
            legendItem(color: episodeColor, label: "Épisodes")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
        }
    }
}

#Preview {
    NavigationStack { StatsView() }
}
