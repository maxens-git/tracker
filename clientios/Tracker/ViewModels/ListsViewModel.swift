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

    func createList(name: String) async {
        do {
            _ = try await api.createList(name: name)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ list: MediaListSummary) async {
        do {
            try await api.deleteList(id: list.id)
            lists.removeAll { $0.id == list.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
