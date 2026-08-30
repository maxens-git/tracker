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
    @State private var listToDelete: MediaListSummary?

    private var systemLists: [MediaListSummary] { viewModel.lists.filter(\.isSystem) }
    private var customLists: [MediaListSummary] { viewModel.lists.filter { !$0.isSystem } }

    var body: some View {
        List {
            if !systemLists.isEmpty {
                Section("Bibliothèque") {
                    ForEach(systemLists) { list in
                        listLink(list)
                    }
                }
            }

            if !customLists.isEmpty {
                Section {
                    ForEach(customLists) { list in
                        listLink(list)
                    }
                } header: {
                    Text("Listes personnelles")
                } footer: {
                    Text("Balayez une liste vers la gauche pour la modifier ou la supprimer.")
                }
            }
        }
        .navigationTitle("Mes listes")
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
        .confirmationDialog(
            "Supprimer « \(listToDelete?.displayName ?? "cette liste") » ?",
            isPresented: Binding(
                get: { listToDelete != nil },
                set: { if !$0 { listToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) {
                guard let list = listToDelete else { return }
                listToDelete = nil
                Task { await viewModel.delete(list) }
            }
            Button("Annuler", role: .cancel) { listToDelete = nil }
        } message: {
            Text("Cette action est définitive. Les médias eux-mêmes ne seront pas supprimés.")
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    private func listLink(_ list: MediaListSummary) -> some View {
        NavigationLink(value: ListRoute(listId: list.routeId, title: list.displayName)) {
            row(for: list)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !list.isSystem {
                Button(role: .destructive) {
                    listToDelete = list
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

    private func create() {
        editingList = nil
        showingEditor = true
    }

    private func edit(_ list: MediaListSummary) {
        editingList = list
        showingEditor = true
    }

    private func row(for list: MediaListSummary) -> some View {
        HStack(spacing: 13) {
            listIcon(for: list)

            VStack(alignment: .leading, spacing: 3) {
                Text(list.displayName)
                    .font(.body.weight(.medium))
                if let description = list.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(list.isSystem ? systemSubtitle(for: list) : "Liste personnelle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Text(list.itemsCount, format: .number)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Color(.tertiarySystemFill), in: .capsule)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func listIcon(for list: MediaListSummary) -> some View {
        let presentation = presentation(for: list)
        Image(systemName: presentation.icon)
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 42, height: 42)
            .background(presentation.tint.gradient,
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .accessibilityHidden(true)
    }

    private func presentation(for list: MediaListSummary) -> (icon: String, tint: Color) {
        switch list.routeId {
        case "watchlist": return ("bookmark.fill", .blue)
        case "seen": return ("checkmark", .green)
        case "liked": return ("heart.fill", .pink)
        default: return ("rectangle.stack.fill", .indigo)
        }
    }

    private func systemSubtitle(for list: MediaListSummary) -> String {
        switch list.routeId {
        case "watchlist": return "Vos prochaines découvertes"
        case "seen": return "Tout ce que vous avez regardé"
        case "liked": return "Vos coups de cœur"
        default: return "Liste système"
        }
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
    @FocusState private var focusedField: Field?

    private enum Field { case name, description }

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
                        .focused($focusedField, equals: .name)
                }
                Section("Description") {
                    TextField("Optionnelle", text: $description, axis: .vertical)
                        .lineLimit(1...4)
                        .focused($focusedField, equals: .description)
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
        .onAppear { focusedField = .name }
    }
}

#Preview {
    NavigationStack { ListsView() }
}
