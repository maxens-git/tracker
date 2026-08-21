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
                                  seen: item.seen)
                            .zoomSource(route, in: zoomNamespace)
                            .task {
                                if item == viewModel.items.last { await viewModel.loadMore() }
                            }
                    }
                    .buttonStyle(.pressableCard)
                }
            }
            .padding(.vertical)

            if viewModel.isLoading {
                ProgressView().padding()
            }
        }
        .navigationTitle(title)
        .errorToast($viewModel.errorMessage)
        .searchable(text: $viewModel.query, prompt: "Rechercher dans la liste")
        .overlay {
            if viewModel.filteredItems.isEmpty && !viewModel.isLoading {
                if viewModel.items.isEmpty {
                    ContentUnavailableView("Liste vide", systemImage: "rectangle.stack",
                                           description: Text("Aucun média dans cette liste."))
                } else {
                    ContentUnavailableView.search(text: viewModel.query)
                }
            }
        }
        .task { await viewModel.loadInitialIfNeeded() }
    }
}
