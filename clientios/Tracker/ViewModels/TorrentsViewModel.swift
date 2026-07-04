//
//  TorrentsViewModel.swift
//  Tracker
//
//  Recherche torrents (Prowlarr) + débridage (AllDebrid), transposé du
//  composant web `Torrents`.
//

import Foundation
import UIKit

@Observable
@MainActor
final class TorrentsViewModel {
    var query = ""
    private(set) var results: [TorrentResult] = []
    private(set) var isLoading = false
    private(set) var hasSearched = false
    var errorMessage: String?

    /// Indexeurs Prowlarr disponibles + ceux sélectionnés (vide = tous).
    private(set) var indexers: [Indexer] = []
    var selectedIndexers: Set<Int> = []

    /// Catégories Prowlarr disponibles + celle sélectionnée (nil = toutes).
    private(set) var categories: [TorrentCategory] = []
    var selectedCategory: Int?

    // ── Débridage ──────────────────────────────────────────────────────────
    /// Magnet en cours de débridage (spinner de la ligne).
    private(set) var debridingMagnet: String?
    /// Popup des liens débridés.
    var showingDebrid = false
    private(set) var debridTorrent: TorrentResult?
    private(set) var debridFiles: [DebridFile] = []

    /// Lien verrouillé en cours de résolution, et liens directs déjà résolus (clé = lien verrouillé).
    private(set) var unlockingLink: String?
    private(set) var resolvingAll = false
    private(set) var resolved: [String: String] = [:]

    private let api = APIService.shared

    // ── Dérivés ──────────────────────────────────────────────────────────────
    var totalDebridSize: Int64 { debridFiles.reduce(0) { $0 + $1.size } }
    var resolvedCount: Int { debridFiles.filter { resolved[$0.link] != nil }.count }
    var hasUnresolved: Bool { debridFiles.contains { resolved[$0.link] == nil } }

    var selectedCategoryName: String {
        guard let id = selectedCategory,
              let cat = categories.first(where: { $0.id == id }) else { return "Toutes les catégories" }
        return cat.name
    }

    var indexersLabel: String {
        switch selectedIndexers.count {
        case 0: return "Tous les indexeurs"
        case 1: return indexers.first { selectedIndexers.contains($0.id) }?.name ?? "1 indexeur"
        default: return "\(selectedIndexers.count) indexeurs"
        }
    }

    func resolvedLink(_ file: DebridFile) -> String? { resolved[file.link] }

    // ── Chargement des filtres ──────────────────────────────────────────────

    /// Silencieux en cas d'échec : on peut toujours chercher sur « tous / toutes ».
    func loadFilters() async {
        guard indexers.isEmpty && categories.isEmpty else { return }
        async let idx = api.torrentIndexers()
        async let cat = api.torrentCategories()
        indexers = (try? await idx) ?? []
        categories = (try? await cat) ?? []
    }

    // ── Recherche ────────────────────────────────────────────────────────────

    func search() async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !isLoading else { return }

        isLoading = true
        hasSearched = true
        errorMessage = nil
        do {
            results = try await api.searchTorrents(query: q,
                                                   indexerIds: Array(selectedIndexers),
                                                   categoryId: selectedCategory)
        } catch {
            results = []
            errorMessage = error.localizedDescription
            Haptics.error()
        }
        isLoading = false
    }

    /// Relance la recherche après un changement de filtre, si une requête est saisie.
    func onFilterChange() async {
        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            await search()
        }
    }

    // ── Débridage ────────────────────────────────────────────────────────────

    func debrid(_ torrent: TorrentResult) async {
        guard debridingMagnet == nil else { return }
        debridingMagnet = torrent.magnetUrl
        defer { debridingMagnet = nil }

        do {
            let result = try await api.debridMagnet(torrent.magnetUrl)
            guard !result.files.isEmpty else {
                errorMessage = "Aucun fichier débridable dans ce torrent."
                Haptics.error()
                return
            }
            debridTorrent = torrent
            debridFiles = result.files
            resolved = [:]
            unlockingLink = nil
            showingDebrid = true
            Haptics.success()
        } catch {
            // Le backend renvoie un message explicite (ex. 409 « non caché »).
            errorMessage = error.localizedDescription
            Haptics.error()
        }
    }

    /// Résout un fichier précis à la demande (1 appel AllDebrid).
    func resolve(_ file: DebridFile) async {
        guard unlockingLink == nil, resolved[file.link] == nil else { return }
        unlockingLink = file.link
        defer { unlockingLink = nil }
        do {
            let res = try await api.unlockLink(file.link)
            resolved[file.link] = res.directLink
            Haptics.success()
        } catch {
            errorMessage = error.localizedDescription
            Haptics.error()
        }
    }

    /// Résout tous les fichiers restants, séquentiellement (un appel après l'autre).
    func resolveAll() async {
        guard unlockingLink == nil, !resolvingAll else { return }
        let pending = debridFiles.filter { resolved[$0.link] == nil }
        guard !pending.isEmpty else { return }

        resolvingAll = true
        for file in pending {
            unlockingLink = file.link
            if let res = try? await api.unlockLink(file.link) {
                resolved[file.link] = res.directLink
            }
        }
        unlockingLink = nil
        resolvingAll = false
        if hasUnresolved {
            errorMessage = "Certains liens n'ont pas pu être obtenus."
            Haptics.error()
        } else {
            Haptics.success()
        }
    }

    // ── Presse-papiers ─────────────────────────────────────────────────────

    func copy(_ link: String) {
        UIPasteboard.general.string = link
        Haptics.success()
    }

    func copyAll() {
        let links = debridFiles.compactMap { resolved[$0.link] }
        guard !links.isEmpty else { return }
        UIPasteboard.general.string = links.joined(separator: "\n")
        Haptics.success()
    }
}
