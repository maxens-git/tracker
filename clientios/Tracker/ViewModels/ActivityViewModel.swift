//
//  ActivityViewModel.swift
//  Tracker
//
//  Flux des dernières actions de l'utilisateur (vu / aimé / listes), paginé,
//  enrichi des titres TMDB côté client.
//

import Foundation

/// Entrée d'activité prête pour l'affichage (titre résolu).
struct ActivityEntry: Identifiable {
    let activity: Activity
    let title: String
    var id: Int { activity.id }
}

@Observable
@MainActor
final class ActivityViewModel {
    private(set) var entries: [ActivityEntry] = []
    private(set) var isLoading = false
    private(set) var totalCount = 0
    var errorMessage: String?

    private var page = 0
    private var totalPages = 1

    private let api = APIService.shared
    private let tmdb = TMDBService.shared

    var canLoadMore: Bool { page < totalPages }

    /// Premier chargement (ignoré si déjà rempli).
    func loadInitial() async {
        guard entries.isEmpty else { return }
        await loadMore()
    }

    /// Recharge depuis le début (pull-to-refresh).
    func reload() async {
        page = 0
        totalPages = 1
        entries = []
        await loadMore()
    }

    func loadMore() async {
        guard !isLoading, page < totalPages else { return }
        isLoading = true
        errorMessage = nil
        do {
            let result = try await api.activity(page: page + 1)
            totalPages = result.totalPages
            totalCount = result.totalCount

            let titles = await resolveTitles(for: result.items)
            entries.append(contentsOf: result.items.map {
                ActivityEntry(activity: $0, title: titles[$0.tmdbId] ?? $0.type2.label)
            })
            page += 1
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Récupère les titres TMDB des médias de la page (chaque média demandé une seule fois).
    private func resolveTitles(for items: [Activity]) async -> [Int: String] {
        var seenKeys = Set<String>()
        var refs: [(id: Int, type: MediaType)] = []
        for a in items where seenKeys.insert("\(a.tmdbId)-\(a.mediaType)").inserted {
            refs.append((a.tmdbId, a.type2))
        }

        let tmdb = self.tmdb
        return await withTaskGroup(of: (Int, String?).self) { group in
            for ref in refs {
                group.addTask {
                    do {
                        let title = ref.type == .movie
                            ? try await tmdb.movie(ref.id).title
                            : try await tmdb.show(ref.id).name
                        return (ref.id, title)
                    } catch {
                        return (ref.id, nil)
                    }
                }
            }
            var map: [Int: String] = [:]
            for await (id, title) in group {
                if let title { map[id] = title }
            }
            return map
        }
    }
}
