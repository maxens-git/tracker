//
//  SearchView.swift
//  Tracker
//
//  Recherche : une `List` standard (comme l'App Store ou Musique) — filtre de
//  type en contrôle segmenté, résultats en lignes avec chevron, recherches
//  récentes supprimables par balayage, tri et genres dans le menu de la barre.
//

import SwiftUI

struct SearchView: View {
    @State private var viewModel = SearchViewModel()
    @State private var showingFilters = false
    @Environment(\.zoomNamespace) private var zoomNamespace

    /// Contrôle segmenté « Tout / Films / Séries » relié au filtre du modèle.
    private var typeSelection: Binding<MediaType?> {
        Binding(get: { viewModel.filter }, set: { viewModel.filter = $0 })
    }

    var body: some View {
        List {
            if !viewModel.allResults.isEmpty {
                typePicker
                resultsSection
            } else if viewModel.query.trimmingCharacters(in: .whitespaces).isEmpty,
                      !viewModel.history.entries.isEmpty {
                recentSection
            }
        }
        .listStyle(.plain)
        .navigationTitle("Recherche")
        .errorToast($viewModel.errorMessage)
        .searchable(text: $viewModel.query, prompt: "Films, séries…")
        .onChange(of: viewModel.query) { _, newValue in viewModel.search(newValue) }
        .task { await viewModel.loadGenresIfNeeded() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Trier par", selection: $viewModel.sort) {
                        ForEach(SearchSort.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    if !viewModel.relevantGenres.isEmpty {
                        Button {
                            showingFilters = true
                        } label: {
                            Label("Genres…", systemImage: "theatermasks")
                        }
                    }
                    if viewModel.hasActiveFilters {
                        Button(role: .destructive) {
                            viewModel.resetFilters()
                        } label: {
                            Label("Réinitialiser les filtres", systemImage: "arrow.counterclockwise")
                        }
                    }
                } label: {
                    Label("Filtres et tri",
                          systemImage: viewModel.hasActiveFilters
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "line.3.horizontal.decrease.circle")
                }
            }
        }
        .sheet(isPresented: $showingFilters) {
            SearchFiltersView(viewModel: viewModel)
        }
        .overlay { emptyState }
    }

    // ── Sections ──────────────────────────────────────────────────────────

    private var typePicker: some View {
        Picker("Type", selection: typeSelection) {
            Text("Tout (\(viewModel.allResults.count))").tag(MediaType?.none)
            Text("Films (\(viewModel.movieCount))").tag(MediaType?.some(.movie))
            Text("Séries (\(viewModel.showCount))").tag(MediaType?.some(.tv))
        }
        .pickerStyle(.segmented)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    private var resultsSection: some View {
        Section {
            ForEach(viewModel.results) { item in
                let route = MediaRoute(tmdbId: item.id, type: item.mediaType)
                NavigationLink(value: route) {
                    resultRow(item)
                        .zoomSource(route, in: zoomNamespace)
                }
            }
        } header: {
            Text("\(viewModel.results.count) résultat\(viewModel.results.count > 1 ? "s" : "")")
        }
    }

    private func resultRow(_ item: TMDBSearchResult) -> some View {
        HStack(spacing: 12) {
            PosterImage(path: item.posterPath, size: "w185")
                .frame(width: 44, height: 66)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayTitle)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text([item.mediaType.label, item.year].compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if viewModel.isSeen(item) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.appGreen)
                    .accessibilityLabel("Déjà vu")
            }
        }
        .padding(.vertical, 4)
    }

    /// Recherches récentes : lignes supprimables par balayage, comme Safari.
    private var recentSection: some View {
        Section {
            ForEach(viewModel.history.entries, id: \.self) { entry in
                Button {
                    viewModel.query = entry
                } label: {
                    Label(entry, systemImage: "clock.arrow.circlepath")
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
            }
            .onDelete { offsets in
                offsets.map { viewModel.history.entries[$0] }.forEach(viewModel.history.remove)
            }
        } header: {
            HStack {
                Text("Recherches récentes")
                Spacer()
                Button("Tout effacer") { viewModel.history.clear() }
                    .font(.footnote)
                    .textCase(nil)
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        let trimmed = viewModel.query.trimmingCharacters(in: .whitespaces)
        if viewModel.isLoading {
            ProgressView()
        } else if !viewModel.allResults.isEmpty && viewModel.results.isEmpty {
            // Des résultats existent mais les filtres genre ne laissent rien passer.
            ContentUnavailableView("Aucun résultat", systemImage: "line.3.horizontal.decrease.circle",
                                   description: Text("Aucun média ne correspond aux filtres choisis."))
        } else if trimmed.isEmpty && viewModel.history.entries.isEmpty {
            ContentUnavailableView("Rechercher", systemImage: "magnifyingglass",
                                   description: Text("Trouvez un film ou une série à suivre."))
        } else if !trimmed.isEmpty && viewModel.allResults.isEmpty {
            ContentUnavailableView.search(text: trimmed)
        }
    }
}

/// Feuille de réglage des filtres (genres) et du tri.
private struct SearchFiltersView: View {
    @Bindable var viewModel: SearchViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Trier par") {
                    Picker("Tri", selection: $viewModel.sort) {
                        ForEach(SearchSort.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                }

                if !viewModel.relevantGenres.isEmpty {
                    Section("Genres") {
                        ForEach(viewModel.relevantGenres) { genre in
                            Button {
                                toggle(genre.id)
                            } label: {
                                HStack {
                                    Text(genre.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if viewModel.selectedGenreIds.contains(genre.id) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.tint)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filtres")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Réinitialiser") { viewModel.resetFilters() }
                        .disabled(!viewModel.hasActiveFilters)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func toggle(_ id: Int) {
        if viewModel.selectedGenreIds.contains(id) {
            viewModel.selectedGenreIds.remove(id)
        } else {
            viewModel.selectedGenreIds.insert(id)
        }
    }
}

#Preview {
    NavigationStack { SearchView() }
}
