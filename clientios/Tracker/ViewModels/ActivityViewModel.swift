//
//  ActivityViewModel.swift
//  Tracker
//
//  Flux des dernières actions de l'utilisateur (vu / aimé / listes), paginé,
//  enrichi des titres TMDB côté client.
//

import Foundation

/// Entrée d'activité prête pour l'affichage (titre + affiche résolus via TMDB).
struct ActivityEntry: Identifiable {
    let activity: Activity
    let title: String
    let posterPath: String?
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
    /// On ne vide pas `entries` avant la réponse : la `List` reste montée, ce qui
    /// évite que SwiftUI annule la tâche de refresh (erreur "cancelled").
    func reload() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            entries = try await fetchPage(1)
            page = 1
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
            entries.append(contentsOf: try await fetchPage(page + 1))
            page += 1
        } catch {
            if !error.isCancellation { errorMessage = error.localizedDescription }
        }
        isLoading = false
    }

    /// Récupère une page et résout les titres TMDB, sans toucher à l'état `entries`/`page`.
    private func fetchPage(_ p: Int) async throws -> [ActivityEntry] {
        let result = try await api.activity(page: p)
        totalPages = result.totalPages
        totalCount = result.totalCount

        let metas = await resolveMeta(for: result.items)
        return result.items.map { activity in
            let meta = metas[activity.tmdbId]
            return ActivityEntry(activity: activity,
                                 title: meta?.title ?? activity.type2.label,
                                 posterPath: activity.posterPath ?? meta?.posterPath)
        }
    }

    /// Métadonnées TMDB (titre + affiche) des médias de la page, chaque média demandé une seule fois.
    /// L'affiche sert de repli pour les actions sans poster stocké (série / saison / épisode).
    private func resolveMeta(for items: [Activity]) async -> [Int: (title: String, posterPath: String?)] {
        var seenKeys = Set<String>()
        var refs: [(id: Int, type: MediaType)] = []
        for a in items where seenKeys.insert("\(a.tmdbId)-\(a.mediaType)").inserted {
            refs.append((a.tmdbId, a.type2))
        }

        let tmdb = self.tmdb
        return await withTaskGroup(of: (Int, String, String?)?.self) { group in
            for ref in refs {
                group.addTask {
                    do {
                        if ref.type == .movie {
                            let m = try await tmdb.movie(ref.id)
                            return (ref.id, m.title, m.posterPath)
                        } else {
                            let s = try await tmdb.show(ref.id)
                            return (ref.id, s.name, s.posterPath)
                        }
                    } catch {
                        return nil
                    }
                }
            }
            var map: [Int: (title: String, posterPath: String?)] = [:]
            for await result in group {
                if let (id, title, poster) = result { map[id] = (title, poster) }
            }
            return map
        }
    }
}
