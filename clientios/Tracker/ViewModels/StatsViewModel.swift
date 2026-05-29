//
//  StatsViewModel.swift
//  Tracker
//

import Foundation

@Observable
@MainActor
final class StatsViewModel {
    private(set) var stats: Stats?
    private(set) var isLoading = false
    var errorMessage: String?

    private let api = APIService.shared

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            stats = try await api.stats()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
