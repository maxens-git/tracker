//
//  LogsViewModel.swift
//  Tracker
//
//  Journal système paginé (« Voir plus »), avec filtre par niveau, recherche
//  texte et action « Vider », en miroir de la page Logs du client web.
//

import Foundation

/// Filtre de niveau proposé dans l'UI. `rawValue` = valeur envoyée au backend.
enum LogLevelFilter: String, CaseIterable, Identifiable {
    case all = "all"
    case information = "Information"
    case warning = "Warning"
    case error = "Error"
    case critical = "Critical"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all:         return "Tous"
        case .information: return "Info"
        case .warning:     return "Warnings"
        case .error:       return "Erreurs"
        case .critical:    return "Critiques"
        }
    }
}

@Observable
@MainActor
final class LogsViewModel {
    private(set) var logs: [SystemLog] = []
    private(set) var isLoading = false
    private(set) var isClearing = false
    private(set) var totalCount = 0
    var errorMessage: String?

    var level: LogLevelFilter = .all
    var search = ""

    private var page = 0
    private var totalPages = 1
    private var requestGeneration = 0

    private struct Filters {
        let level: LogLevelFilter
        let search: String
    }
    // La pagination conserve les filtres de la liste affichée, même pendant
    // la saisie d'une recherche qui n'a pas encore été validée.
    private var appliedFilters = Filters(level: .all, search: "")

    private let api = APIService.shared

    var canLoadMore: Bool { page < totalPages }

    /// Premier chargement (ignoré si déjà rempli).
    func loadInitial() async {
        guard logs.isEmpty, !isLoading else { return }
        await loadFirstPage(clear: true)
    }

    /// Recharge depuis le début (pull-to-refresh). On ne vide pas `logs` avant la
    /// réponse : la liste reste montée, ce qui évite l'auto-annulation du refresh.
    func refresh() async {
        await loadFirstPage(clear: false)
    }

    func loadMore() async {
        guard !isLoading, page < totalPages else { return }
        let generation = requestGeneration
        let nextPage = page + 1
        let filters = appliedFilters
        isLoading = true
        errorMessage = nil
        defer {
            if generation == requestGeneration { isLoading = false }
        }
        do {
            let result = try await api.logs(page: nextPage, level: filters.level.rawValue, search: filters.search)
            guard generation == requestGeneration, !Task.isCancelled else { return }
            apply(result, page: nextPage)
        } catch {
            guard generation == requestGeneration else { return }
            if !error.isCancellation { errorMessage = error.localizedDescription }
        }
    }

    /// Applique un nouveau filtre (niveau / recherche) : réinitialise puis recharge.
    func applyFilters() async {
        await loadFirstPage(clear: true)
    }

    func clear() async {
        guard !isClearing else { return }
        isClearing = true
        errorMessage = nil
        do {
            try await api.clearLogs()
            await loadFirstPage(clear: true)
        } catch {
            if !error.isCancellation { errorMessage = error.localizedDescription }
        }
        isClearing = false
    }

    private func loadFirstPage(clear: Bool) async {
        requestGeneration += 1
        let generation = requestGeneration
        let filters = Filters(level: level, search: search)
        if clear {
            logs = []
            page = 0
            totalPages = 1
            totalCount = 0
            appliedFilters = filters
        }
        isLoading = true
        errorMessage = nil
        defer {
            if generation == requestGeneration { isLoading = false }
        }
        do {
            let result = try await api.logs(page: 1, level: filters.level.rawValue, search: filters.search)
            guard generation == requestGeneration, !Task.isCancelled else { return }
            appliedFilters = filters
            apply(result, page: 1)
        } catch {
            guard generation == requestGeneration else { return }
            if !error.isCancellation { errorMessage = error.localizedDescription }
        }
    }

    private func apply(_ result: PaginatedResult<SystemLog>, page loadedPage: Int) {
        if loadedPage == 1 {
            logs = result.items
        } else {
            logs.append(contentsOf: result.items)
        }
        page = loadedPage
        totalPages = result.totalPages
        totalCount = result.totalCount
    }
}
