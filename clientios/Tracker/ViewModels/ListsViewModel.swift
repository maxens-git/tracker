//
//  ListsViewModel.swift
//  Tracker
//

import Foundation

@Observable
@MainActor
final class ListsViewModel {
    private(set) var lists: [MediaListSummary] = []
    private(set) var isLoading = false
    var errorMessage: String?

    private let api = APIService.shared

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            lists = try await api.lists()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func createList(name: String, description: String = "", icon: String = "") async {
        do {
            _ = try await api.createList(name: name,
                                         description: description.isEmpty ? nil : description,
                                         icon: icon.isEmpty ? nil : icon)
            await load()
            Haptics.success()
        } catch {
            errorMessage = error.localizedDescription
            Haptics.error()
        }
    }

    /// Modifie une liste personnalisée (nom / icône / description).
    func update(_ list: MediaListSummary, name: String, description: String, icon: String) async {
        do {
            try await api.updateList(id: list.id, name: name, description: description, icon: icon)
            await load()
            Haptics.success()
        } catch {
            errorMessage = error.localizedDescription
            Haptics.error()
        }
    }

    func delete(_ list: MediaListSummary) async {
        do {
            try await api.deleteList(id: list.id)
            lists.removeAll { $0.id == list.id }
            Haptics.warning()
        } catch {
            errorMessage = error.localizedDescription
            Haptics.error()
        }
    }
}
