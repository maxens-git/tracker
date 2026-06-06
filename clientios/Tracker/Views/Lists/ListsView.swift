//
//  ListsView.swift
//  Tracker
//

import SwiftUI

struct ListsView: View {
    @State private var viewModel = ListsViewModel()
    @State private var showingNewList = false
    @State private var newListName = ""

    var body: some View {
        List {
            if !viewModel.lists.isEmpty {
                Section {
                    ForEach(viewModel.lists) { list in
                        NavigationLink(value: ListRoute(listId: list.routeId, title: list.name)) {
                            row(for: list)
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.appSurface)
                                .padding(.vertical, 3)
                        )
                    }
                    .onDelete(perform: deleteLists)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Listes")
        .overlay {
            if viewModel.isLoading && viewModel.lists.isEmpty {
                ProgressView()
            } else if let error = viewModel.errorMessage, viewModel.lists.isEmpty {
                ContentUnavailableView("Erreur de chargement", systemImage: "wifi.slash",
                                       description: Text(error))
            } else if viewModel.lists.isEmpty {
                ContentUnavailableView("Aucune liste", systemImage: "list.bullet",
                                       description: Text("Créez une liste pour organiser vos médias."))
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newListName = ""
                    showingNewList = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("Nouvelle liste", isPresented: $showingNewList) {
            TextField("Nom", text: $newListName)
            Button("Annuler", role: .cancel) {}
            Button("Créer") {
                let name = newListName.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return }
                Task { await viewModel.createList(name: name) }
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    private func row(for list: MediaListSummary) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.tint.opacity(0.15))
                    .frame(width: 44, height: 44)
                Text(list.icon ?? String(list.name.prefix(1)))
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(list.name)
                    .font(.body.weight(.semibold))
                Text("\(list.itemsCount) élément\(list.itemsCount > 1 ? "s" : "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let description = list.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func deleteLists(at offsets: IndexSet) {
        for index in offsets {
            let list = viewModel.lists[index]
            guard !list.isSystem else { continue }
            Task { await viewModel.delete(list) }
        }
    }
}

#Preview {
    NavigationStack { ListsView() }
}
