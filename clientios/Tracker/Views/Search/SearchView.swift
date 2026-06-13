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
                VStack(spacing: 12) {
                    Picker("Filtre", selection: $viewModel.filter) {
                        Text("Tout (\(viewModel.allResults.count))").tag(MediaType?.none)
                        Text("Films (\(viewModel.movieCount))").tag(MediaType?.some(.movie))
                        Text("Séries (\(viewModel.showCount))").tag(MediaType?.some(.tv))
                    }
                    .pickerStyle(.segmented)

                    Button {
                        showingFilters = true
                    } label: {
                        HStack {
                            Image(systemName: viewModel.hasActiveFilters
                                  ? "line.3.horizontal.decrease.circle.fill"
                                  : "line.3.horizontal.decrease.circle")
                            Text("Filtres & tri")
                            if viewModel.hasActiveFilters {
                                Circle()
                                    .fill(Color.accentColor)
                                    .frame(width: 7, height: 7)
                            }
                            Spacer()
                            Text(viewModel.sort.label)
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(viewModel.hasActiveFilters ? Color.accentColor : .primary)
                    }
                    .buttonStyle(.plain)
                }
                .padding([.horizontal, .top])
            }

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
            } else if viewModel.results.isEmpty {
                emptyState
            } else {
                MediaGrid {
                    ForEach(viewModel.results) { item in
                        NavigationLink(value: MediaRoute(tmdbId: item.id, type: item.mediaType)) {
                            MediaCard(posterPath: item.posterPath,
                                      title: item.displayTitle,
                                      subtitle: item.year,
                                      seen: viewModel.isSeen(item))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical)
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

    @ViewBuilder
    private var emptyState: some View {
        let trimmed = viewModel.query.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            ContentUnavailableView("Rechercher", systemImage: "magnifyingglass",
                                   description: Text("Trouvez un film ou une série à suivre."))
                .padding(.top, 60)
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
