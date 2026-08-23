//
//  ListsView.swift
//  Tracker
//

import SwiftUI

struct ListsView: View {
    @State private var viewModel = ListsViewModel()
    @State private var showingEditor = false
    /// Liste en cours d'édition ; `nil` = création d'une nouvelle liste.
    @State private var editingList: MediaListSummary?

    var body: some View {
        List {
            ForEach(viewModel.lists) { list in
                NavigationLink(value: ListRoute(listId: list.routeId, title: list.name)) {
                    row(for: list)
                }
                // Modifier / supprimer : réservé aux listes non-système.
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if !list.isSystem {
                        Button(role: .destructive) {
                            Task { await viewModel.delete(list) }
                        } label: {
                            Label("Supprimer", systemImage: "trash")
                        }
                        Button {
                            edit(list)
                        } label: {
                            Label("Modifier", systemImage: "pencil")
                        }
                        .tint(.accentColor)
                    }
                }
            }
        }
        .navigationTitle("Listes")
        .errorToast($viewModel.errorMessage)
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
                    create()
                } label: {
                    Label("Nouvelle liste", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            ListEditorSheet(list: editingList) { name, description in
                Task {
                    if let editingList {
                        await viewModel.update(editingList, name: name, description: description)
                    } else {
                        await viewModel.createList(name: name, description: description)
                    }
                }
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    private func create() {
        editingList = nil
        showingEditor = true
    }

    private func edit(_ list: MediaListSummary) {
        editingList = list
        showingEditor = true
    }

    private func row(for list: MediaListSummary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(list.name)
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
        .padding(.vertical, 2)
    }
}

// MARK: - Éditeur de liste (création / modification)

/// Feuille de saisie réutilisée pour créer ou modifier une liste personnalisée.
private struct ListEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let isEditing: Bool
    private let onSave: (_ name: String, _ description: String) -> Void

    @State private var name: String
    @State private var description: String

    init(list: MediaListSummary?,
         onSave: @escaping (_ name: String, _ description: String) -> Void) {
        self.isEditing = list != nil
        self.onSave = onSave
        _name = State(initialValue: list?.name ?? "")
        _description = State(initialValue: list?.description ?? "")
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nom", text: $name)
                }
                Section("Description") {
                    TextField("Optionnelle", text: $description, axis: .vertical)
                        .lineLimit(1...4)
                }
            }
            .navigationTitle(isEditing ? "Modifier la liste" : "Nouvelle liste")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        onSave(trimmedName,
                               description.trimmingCharacters(in: .whitespaces))
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    NavigationStack { ListsView() }
}
