//
//  ReleaseCalendarView.swift
//  Tracker
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
        VStack(spacing: 0) {
            Picker("Affichage", selection: $mode) {
                Text("Liste").tag(Mode.list)
                Text("Calendrier").tag(Mode.calendar)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Group {
                switch mode {
                case .list: listView
                case .calendar: calendarView
                }
            }
        }
        .navigationTitle("Sorties")
        .background(Color.appBackground.ignoresSafeArea())
        // États vides / chargement en overlay : le fond chaud `appBackground`
        // couvre tout l'écran quand il n'y a rien à afficher.
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
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.load(forceRefresh: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
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
            ForEach(viewModel.items) { item in
                releaseLink(item)
            }

            if !viewModel.pendingItems.isEmpty {
                // Lignes simples (et non une Section) pour garder un fond transparent :
                // le header/footer d'une Section affiche un rectangle blanc collé aux bords.
                Text("À venir · date à confirmer")
                    .font(.headline)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 18, leading: 16, bottom: 2, trailing: 16))

                ForEach(viewModel.pendingItems) { item in
                    releaseLink(item)
                }

                Text("Annoncé sur TMDB sans date. Basculera dans le calendrier dès qu'une date sera publiée.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 10, trailing: 16))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable { await viewModel.load(forceRefresh: true) }
    }

    private func releaseLink(_ item: ReleaseCalendarItem) -> some View {
        releaseNavigationRow(item)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
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
            VStack(spacing: 16) {
                MonthCalendarView(month: $visibleMonth,
                                  selectedDay: $selectedDay,
                                  daysWithReleases: Set(itemsByDay.keys))
                    .padding(.horizontal)

                selectedDayList

                pendingList
            }
            .padding(.vertical, 8)
        }
        .scrollContentBackground(.hidden)
        .refreshable { await viewModel.load(forceRefresh: true) }
    }

    /// Saisons/films annoncés sans date, affichés sous le calendrier (jamais sur une case).
    @ViewBuilder
    private var pendingList: some View {
        if !viewModel.pendingItems.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("À venir · date à confirmer")
                    .font(.headline)
                    .padding(.horizontal, 4)

                ForEach(viewModel.pendingItems) { item in
                    calendarReleaseRow(item)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var selectedDayList: some View {
        let dayItems = selectedDay.flatMap { itemsByDay[$0] } ?? []
        VStack(alignment: .leading, spacing: 10) {
            if let selectedDay {
                Text(DateOnlyFormatter.display(selectedDay))
                    .font(.headline)
                    .padding(.horizontal, 4)
            }

            if dayItems.isEmpty {
                Text("Aucune sortie ce jour.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            } else {
                ForEach(dayItems) { item in
                    calendarReleaseRow(item)
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

    /// Ligne cliquable dans une `List` : l'astuce ZStack + lien invisible évite le
    /// double chevron ajouté automatiquement par `List` autour d'un `NavigationLink`.
    private func releaseNavigationRow(_ item: ReleaseCalendarItem) -> some View {
        ZStack {
            releaseRow(item)
                .allowsHitTesting(false)

            NavigationLink(value: MediaRoute(tmdbId: item.tmdbId, type: item.type)) {
                Color.clear
            }
            .opacity(0)
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
    }

    /// Ligne cliquable hors `List` (vue calendrier) : le `NavigationLink` enveloppe
    /// directement la carte, sinon le lien invisible en `opacity(0)` ne reçoit pas les taps.
    private func calendarReleaseRow(_ item: ReleaseCalendarItem) -> some View {
        NavigationLink(value: MediaRoute(tmdbId: item.tmdbId, type: item.type)) {
            releaseRow(item)
        }
        .buttonStyle(.plain)
    }

    private func releaseRow(_ item: ReleaseCalendarItem) -> some View {
        HStack(spacing: 12) {
            PosterImage(path: item.posterPath)
                .frame(width: 46, height: 69)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.kind.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tint)
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(item.pending ? "À confirmer" : DateOnlyFormatter.display(item.date))
                    .font(.caption2)
                    .foregroundStyle(item.pending ? Color.accentColor : Color.secondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .glassPanel()
    }
}

#Preview {
    NavigationStack { ReleaseCalendarView() }
}
