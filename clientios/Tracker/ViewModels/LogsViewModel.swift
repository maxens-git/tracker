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

    private let api = APIService.shared

    var canLoadMore: Bool { page < totalPages }

    /// Premier chargement (ignoré si déjà rempli).
    func loadInitial() async {
        guard logs.isEmpty else { return }
        await loadMore()
    }

    /// Recharge depuis le début (pull-to-refresh). On ne vide pas `logs` avant la
    /// réponse : la liste reste montée, ce qui évite l'auto-annulation du refresh.
    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            let result = try await api.logs(page: 1, level: level.rawValue, search: search)
            apply(result, reset: true)
        } catch {
            if !error.isCancellation { errorMessage = error.localizedDescription }
        }
        isLoading = false
    }

    func loadMore() async {
        guard !isLoading, page < totalPages else { return }
        isLoading = true
        errorMessage = nil
        do {
            let result = try await api.logs(page: page + 1, level: level.rawValue, search: search)
            apply(result, reset: false)
        } catch {
            if !error.isCancellation { errorMessage = error.localizedDescription }
        }
        isLoading = false
    }

    /// Applique un nouveau filtre (niveau / recherche) : réinitialise puis recharge.
    func applyFilters() async {
        page = 0
        totalPages = 1
        logs = []
        await loadMore()
    }

    func clear() async {
        guard !isClearing else { return }
        isClearing = true
        errorMessage = nil
        do {
            try await api.clearLogs()
            page = 0
            totalPages = 1
            logs = []
            totalCount = 0
            await loadMore()
        } catch {
            if !error.isCancellation { errorMessage = error.localizedDescription }
        }
        isClearing = false
    }

    private func apply(_ result: PaginatedResult<SystemLog>, reset: Bool) {
        if reset {
            logs = result.items
            page = 1
        } else {
            logs.append(contentsOf: result.items)
            page += 1
        }
        totalPages = result.totalPages
        totalCount = result.totalCount
    }
}
