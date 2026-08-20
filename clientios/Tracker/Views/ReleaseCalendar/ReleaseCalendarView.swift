//
//  ReleaseCalendarView.swift
//  Tracker
//
//  Sorties suivies : soit une liste groupée standard, soit une grille mensuelle
//  avec les sorties du jour sélectionné dessous. Le sélecteur d'affichage est un
//  contrôle segmenté placé dans la barre de navigation, comme dans Calendrier.
//

import SwiftUI

struct ReleaseCalendarView: View {
    private enum Mode: Hashable { case list, calendar }

    @State private var viewModel = ReleaseCalendarViewModel()
    @State private var mode: Mode = .list
    @State private var selectedDay: String?
    @State private var visibleMonth = Date()

    /// Sorties regroupées par jour (`yyyy-MM-dd`), pour marquer les cases du calendrier.
    private var itemsByDay: [String: [ReleaseCalendarItem]] {
        Dictionary(grouping: viewModel.items, by: { $0.date })
    }

    var body: some View {
        Group {
            switch mode {
            case .list: listView
            case .calendar: calendarView
            }
        }
        .navigationTitle("Sorties")
        .overlay {
            if viewModel.isLoading && viewModel.items.isEmpty {
                ProgressView()
            } else if viewModel.trackedCount == 0 && !viewModel.isLoading {
                ContentUnavailableView("Aucun média suivi", systemImage: "bell",
                                       description: Text("Ajoutez un film ou une série depuis sa fiche détail."))
            } else if viewModel.items.isEmpty && viewModel.pendingItems.isEmpty && !viewModel.isLoading {
                ContentUnavailableView("Aucune sortie à venir", systemImage: "calendar",
                                       description: Text("Les médias suivis sont enregistrés, mais TMDB ne remonte pas encore de prochaine date."))
            }
        }
        .errorToast($viewModel.errorMessage)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Affichage", selection: $mode) {
                    Text("Liste").tag(Mode.list)
                    Text("Calendrier").tag(Mode.calendar)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 240)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.load(forceRefresh: true) }
                } label: {
                    Label("Rafraîchir", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }
        }
        .task { await viewModel.load() }
        .onChange(of: viewModel.items) { _, _ in ensureSelection() }
        .onChange(of: mode) { _, _ in ensureSelection() }
    }

    // ── Vue liste ────────────────────────────────────────────────────────────

    private var listView: some View {
        List {
            if !viewModel.items.isEmpty {
                Section {
                    ForEach(viewModel.items) { item in
                        releaseLink(item)
                    }
                }
            }

            if !viewModel.pendingItems.isEmpty {
                Section {
                    ForEach(viewModel.pendingItems) { item in
                        releaseLink(item)
                    }
                } header: {
                    Text("À venir · date à confirmer")
                } footer: {
                    Text("Annoncé sur TMDB sans date. Basculera dans le calendrier dès qu'une date sera publiée.")
                }
            }
        }
        .refreshable { await viewModel.load(forceRefresh: true) }
    }

    private func releaseLink(_ item: ReleaseCalendarItem) -> some View {
        NavigationLink(value: MediaRoute(tmdbId: item.tmdbId, type: item.type)) {
            releaseRow(item)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                Task { await viewModel.remove(item) }
            } label: {
                Label("Ne plus suivre", systemImage: "bell.slash")
            }
        }
    }

    // ── Vue calendrier ─────────────────────────────────────────────────────────

    private var calendarView: some View {
        ScrollView {
            VStack(spacing: 20) {
                MonthCalendarView(month: $visibleMonth,
                                  selectedDay: $selectedDay,
                                  daysWithReleases: Set(itemsByDay.keys))
                    .padding(.horizontal)

                selectedDayList

                pendingList
            }
            .padding(.vertical, 12)
        }
        .background(Color.appBackground)
        .refreshable { await viewModel.load(forceRefresh: true) }
    }

    /// Saisons/films annoncés sans date, affichés sous le calendrier (jamais sur une case).
    @ViewBuilder
    private var pendingList: some View {
        if !viewModel.pendingItems.isEmpty {
            dayGroup(title: "À venir · date à confirmer", items: viewModel.pendingItems)
        }
    }

    @ViewBuilder
    private var selectedDayList: some View {
        let dayItems = selectedDay.flatMap { itemsByDay[$0] } ?? []
        if let selectedDay {
            dayGroup(title: DateOnlyFormatter.display(selectedDay), items: dayItems)
        }
    }

    /// Un titre de section puis les sorties correspondantes, dans une carte
    /// groupée (rendu d'une section de liste, hors `List`).
    private func dayGroup(title: String, items: [ReleaseCalendarItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 16)

            if items.isEmpty {
                Text("Aucune sortie ce jour.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .cardBackground()
            } else {
                CardGroup {
                    ForEach(items) { item in
                        NavigationLink(value: MediaRoute(tmdbId: item.tmdbId, type: item.type)) {
                            HStack {
                                releaseRow(item)
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if item.id != items.last?.id {
                            RowDivider(leadingInset: 70)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }

    /// Sélectionne par défaut le premier jour à venir (une seule fois) et cale le mois dessus.
    private func ensureSelection() {
        guard selectedDay == nil, let first = viewModel.items.first else { return }
        selectedDay = first.date
        if let date = DateOnlyFormatter.date(from: first.date) { visibleMonth = date }
    }

    private func releaseRow(_ item: ReleaseCalendarItem) -> some View {
        HStack(spacing: 12) {
            PosterImage(path: item.posterPath)
                .frame(width: 44, height: 66)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.kind.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tint)
                Text(item.title)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(item.pending ? "À confirmer" : DateOnlyFormatter.display(item.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack { ReleaseCalendarView() }
}
