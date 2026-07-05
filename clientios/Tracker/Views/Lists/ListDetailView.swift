//
//  ListDetailView.swift
//  Tracker
//

import SwiftUI

struct ListDetailView: View {
    @State private var viewModel: ListDetailViewModel
    private let title: String

    init(listId: String, title: String) {
        _viewModel = State(initialValue: ListDetailViewModel(listId: listId))
        self.title = title
    }

    var body: some View {
        ScrollView {
            MediaGrid(spacing: 12) {
                ForEach(viewModel.filteredItems) { item in
                    NavigationLink(value: MediaRoute(tmdbId: item.tmdbId, type: item.type)) {
                        MediaCard(posterPath: viewModel.posterPath(for: item),
                                  title: viewModel.title(for: item),
                                  subtitle: viewModel.year(for: item),
                                  seen: item.seen)
                            .task {
                                if item == viewModel.items.last { await viewModel.loadMore() }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical)

            if viewModel.isLoading {
                ProgressView().padding()
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
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
