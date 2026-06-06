//
//  SearchView.swift
//  Tracker
//

import SwiftUI

struct SearchView: View {
    @State private var viewModel = SearchViewModel()

    var body: some View {
        ScrollView {
            if !viewModel.allResults.isEmpty {
                Picker("Filtre", selection: $viewModel.filter) {
                    Text("Tout (\(viewModel.allResults.count))").tag(MediaType?.none)
                    Text("Films (\(viewModel.movieCount))").tag(MediaType?.some(.movie))
                    Text("Séries (\(viewModel.showCount))").tag(MediaType?.some(.tv))
                }
                .pickerStyle(.segmented)
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
                                      subtitle: item.year)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("Recherche")
        .searchable(text: $viewModel.query, prompt: "Films, séries…")
        .onChange(of: viewModel.query) { viewModel.search() }
    }

    @ViewBuilder
    private var emptyState: some View {
        let trimmed = viewModel.query.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            ContentUnavailableView("Rechercher", systemImage: "magnifyingglass",
                                   description: Text("Trouvez un film ou une série à suivre."))
                .padding(.top, 60)
        } else {
            ContentUnavailableView.search(text: trimmed)
                .padding(.top, 60)
        }
    }
}

#Preview {
    NavigationStack { SearchView() }
}
