//
//  SearchView.swift
//  Tracker
//

import SwiftUI

struct SearchView: View {
    @State private var viewModel = SearchViewModel()
    @State private var showingFilters = false

    var body: some View {
        ScrollView {
            if !viewModel.allResults.isEmpty {
                filterBar
            }

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
            } else if viewModel.results.isEmpty {
                emptyState
            } else {
                resultsList
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Recherche")
        .errorToast($viewModel.errorMessage)
        .searchable(text: $viewModel.query, prompt: "Films, séries…")
        .onChange(of: viewModel.query) { viewModel.search() }
        .task { await viewModel.loadGenresIfNeeded() }
        .sheet(isPresented: $showingFilters) {
            SearchFiltersView(viewModel: viewModel)
        }
    }

    /// Rangée de chips de type (Tout / Films / Séries) + accès aux filtres & tri,
    /// à la place du segmented control : même vocabulaire que le reste de l'app.
    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 9) {
                    FilterChip(label: "Tout (\(viewModel.allResults.count))",
                               isSelected: viewModel.filter == nil) {
                        viewModel.filter = nil
                    }
                    FilterChip(label: "Films (\(viewModel.movieCount))",
                               isSelected: viewModel.filter == .movie) {
                        viewModel.filter = .movie
                    }
                    FilterChip(label: "Séries (\(viewModel.showCount))",
                               isSelected: viewModel.filter == .tv) {
                        viewModel.filter = .tv
                    }
                }
                .padding(.horizontal, 20)
            }

            Button {
                showingFilters = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.hasActiveFilters
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "line.3.horizontal.decrease.circle")
                    Text("Filtres & tri")
                    if viewModel.hasActiveFilters {
                        Circle()
                            .fill(Color.appAccent)
                            .frame(width: 7, height: 7)
                    }
                    Spacer()
                    Text(viewModel.sort.label)
                        .foregroundStyle(.secondary)
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(viewModel.hasActiveFilters ? Color.appAccent : .primary)
                .padding(.horizontal, 20)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }

    /// Résultats en liste encastrée (affiche + titre + métadonnées), conformément
    /// à la maquette : plus lisible qu'une grille quand les titres sont longs.
    private var resultsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(viewModel.results.count) résultat\(viewModel.results.count > 1 ? "s" : "")")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)

            GlassRowGroup {
                ForEach(viewModel.results) { item in
                    NavigationLink(value: MediaRoute(tmdbId: item.id, type: item.mediaType)) {
                        resultRow(item)
                    }
                    .buttonStyle(.plain)

                    if item.id != viewModel.results.last?.id {
                        GlassRowDivider(leadingInset: 15)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 16)
        // Le champ de recherche flotte au-dessus du contenu (iOS 26) : on
        // dégage assez de place pour que la dernière ligne reste atteignable.
        .padding(.bottom, 90)
    }

    private func resultRow(_ item: TMDBSearchResult) -> some View {
        HStack(spacing: 14) {
            PosterImage(path: item.posterPath, size: "w185")
                .frame(width: 50, height: 74)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayTitle)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text([item.mediaType.label, item.year].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if viewModel.isSeen(item) {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.appGreen))
                    .accessibilityLabel("Déjà vu")
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var emptyState: some View {
        let trimmed = viewModel.query.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            if viewModel.history.entries.isEmpty {
                ContentUnavailableView("Rechercher", systemImage: "magnifyingglass",
                                       description: Text("Trouvez un film ou une série à suivre."))
                    .padding(.top, 60)
            } else {
                recentSearches
            }
        } else if !viewModel.allResults.isEmpty {
            // Des résultats existent mais les filtres genre ne laissent rien passer.
            ContentUnavailableView("Aucun résultat", systemImage: "line.3.horizontal.decrease.circle",
                                   description: Text("Aucun média ne correspond aux filtres choisis."))
                .padding(.top, 60)
        } else {
            ContentUnavailableView.search(text: trimmed)
                .padding(.top, 60)
        }
    }

    /// Liste des recherches récentes (affichée quand le champ est vide).
    private var recentSearches: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader("Recherches récentes")
                Spacer()
                Button("Tout effacer") {
                    viewModel.history.clear()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                ForEach(Array(viewModel.history.entries.enumerated()), id: \.element) { index, entry in
                    HStack(spacing: 12) {
                        Button {
                            viewModel.query = entry
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                Text(entry)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Button {
                            viewModel.history.remove(entry)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Retirer « \(entry) »")
                    }
                    .padding(.vertical, 12)

                    if index < viewModel.history.entries.count - 1 {
                        Divider().padding(.leading, 28)
                    }
                }
            }
            .padding(.horizontal, 14)
            .glassPanel()
        }
        .padding()
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
                                            .foregroundStyle(Color.accentColor)
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
