//
//  ListDetailView.swift
//  Tracker
//

import SwiftUI

struct ListDetailView: View {
    @State private var viewModel: ListDetailViewModel
    private let listId: String
    private let title: String
    @Environment(\.zoomNamespace) private var zoomNamespace

    init(listId: String, title: String) {
        _viewModel = State(initialValue: ListDetailViewModel(listId: listId))
        self.listId = listId
        self.title = title
    }

    var body: some View {
        ScrollView {
            MediaGrid(spacing: 16) {
                ForEach(viewModel.filteredItems) { item in
                    let route = MediaRoute(tmdbId: item.tmdbId, type: item.type, source: "list-\(listId)")
                    NavigationLink(value: route) {
                        MediaCard(posterPath: viewModel.posterPath(for: item),
                                  title: viewModel.title(for: item),
                                  subtitle: viewModel.year(for: item),
                                  seen: item.seen,
                                  watchCount: item.watchCount ?? 0)
                            .zoomSource(route, in: zoomNamespace)
                            .task {
                                if !viewModel.isSearching, item.id == viewModel.items.last?.id {
                                    await viewModel.loadMore()
                                }
                            }
                    }
                    .buttonStyle(.pressableCard)
                }
            }
            .padding(.vertical)

            if viewModel.isLoading {
                ProgressView().padding()
            } else if let error = viewModel.errorMessage, !viewModel.items.isEmpty {
                VStack(spacing: 8) {
                    Text(error).foregroundStyle(.secondary)
                    Button("Réessayer") { Task { await viewModel.retry() } }
                }
                .padding()
            } else if viewModel.hasMore && !viewModel.items.isEmpty {
                Button("Charger la suite") { Task { await viewModel.loadMore() } }
                    .buttonStyle(.bordered)
                    .padding()
            }
        }
        .navigationTitle(title)
        .searchable(text: $viewModel.query, prompt: "Rechercher dans la liste")
        .overlay {
            if viewModel.filteredItems.isEmpty && !viewModel.isLoading {
                if let error = viewModel.errorMessage {
                    ContentUnavailableView {
                        Label("Erreur de chargement", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Réessayer") { Task { await viewModel.retry() } }
                            .buttonStyle(.glassProminent)
                    }
                } else if viewModel.items.isEmpty {
                    ContentUnavailableView("Liste vide", systemImage: "rectangle.stack",
                                           description: Text("Aucun média dans cette liste."))
                } else {
                    ContentUnavailableView.search(text: viewModel.query)
                }
            }
        }
        .task { await viewModel.refresh() }
        .task(id: viewModel.query) { await viewModel.loadSearchResults() }
        .refreshable { await viewModel.refresh() }
    }
}
