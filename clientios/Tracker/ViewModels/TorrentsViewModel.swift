//
//  TorrentsViewModel.swift
//  Tracker
//
//  Recherche torrents (Prowlarr) + débridage (AllDebrid), transposé du
//  composant web `Torrents`.
//

import Foundation
import UIKit

/// Onglet de la page torrents : résultats de recherche ou marque-pages.
enum TorrentsTab: Hashable { case results, bookmarks }

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
    /// Fichiers cochés (par lien verrouillé) pour la copie groupée. Un lien
    /// fraîchement résolu y est ajouté automatiquement ; l'utilisateur peut
    /// ensuite décocher ce qu'il ne veut pas copier.
    var selectedLinks: Set<String> = []

    // ── Marque-pages ─────────────────────────────────────────────────────────
    /// Onglet courant (résultats / marque-pages). On ouvre sur les marque-pages ;
    /// une recherche bascule automatiquement vers les résultats (cf. `search()`).
    var tab: TorrentsTab = .bookmarks
    private(set) var bookmarks: [TorrentBookmark] = []
    /// Magnet du marque-page en cours d'ajout/suppression (spinner de la ligne).
    private(set) var bookmarkingMagnet: String?

    private let api = APIService.shared

    // ── Dérivés ──────────────────────────────────────────────────────────────
    var totalDebridSize: Int64 { debridFiles.reduce(0) { $0 + $1.size } }
    var resolvedCount: Int { debridFiles.filter { resolved[$0.link] != nil }.count }
    var hasUnresolved: Bool { debridFiles.contains { resolved[$0.link] == nil } }

    /// Liens verrouillés déjà résolus, dans l'ordre des fichiers.
    private var resolvedFileKeys: [String] { debridFiles.map(\.link).filter { resolved[$0] != nil } }
    /// Nombre de fichiers cochés.
    var selectedCount: Int { selectedLinks.count }
    /// Vrai quand tous les fichiers résolus sont cochés.
    var allResolvedSelected: Bool {
        let keys = resolvedFileKeys
        return !keys.isEmpty && selectedLinks.isSuperset(of: keys)
    }
    func isSelected(_ file: DebridFile) -> Bool { selectedLinks.contains(file.link) }

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

        // Une recherche amène toujours sur l'onglet des résultats.
        tab = .results
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
            selectedLinks = []
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
            selectedLinks.insert(file.link)   // coché par défaut, décochable ensuite
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
                selectedLinks.insert(file.link)   // coché par défaut, décochable ensuite
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

    // ── Sélection multiple ─────────────────────────────────────────────────

    /// Coche / décoche un fichier (uniquement s'il est déjà résolu).
    func toggleSelection(_ file: DebridFile) {
        guard resolved[file.link] != nil else { return }
        if selectedLinks.contains(file.link) {
            selectedLinks.remove(file.link)
        } else {
            selectedLinks.insert(file.link)
        }
    }

    /// Coche tout / décoche tout (parmi les fichiers résolus).
    func toggleSelectAll() {
        if allResolvedSelected {
            selectedLinks.removeAll()
        } else {
            selectedLinks = Set(resolvedFileKeys)
        }
    }

    /// Copie les liens directs des fichiers cochés, un par ligne.
    func copySelected() {
        let links = debridFiles
            .filter { selectedLinks.contains($0.link) }
            .compactMap { resolved[$0.link] }
        guard !links.isEmpty else { return }
        UIPasteboard.general.string = links.joined(separator: "\n")
        Haptics.success()
    }

    // ── Marque-pages ───────────────────────────────────────────────────────

    /// Silencieux en cas d'échec : les marque-pages sont secondaires, la recherche reste utilisable.
    func loadBookmarks() async {
        if let list = try? await api.torrentBookmarks() { bookmarks = list }
    }

    func isBookmarked(_ magnetUrl: String) -> Bool {
        bookmarks.contains { $0.magnetUrl == magnetUrl }
    }

    func isBookmarking(_ magnetUrl: String) -> Bool {
        bookmarkingMagnet == magnetUrl
    }

    private func bookmark(for magnetUrl: String) -> TorrentBookmark? {
        bookmarks.first { $0.magnetUrl == magnetUrl }
    }

    /// Ajoute ou retire un torrent des marque-pages (mise à jour optimiste avec rollback).
    func toggleBookmark(_ torrent: TorrentResult) async {
        guard bookmarkingMagnet == nil else { return }
        bookmarkingMagnet = torrent.magnetUrl
        defer { bookmarkingMagnet = nil }

        if let existing = bookmark(for: torrent.magnetUrl) {
            bookmarks.removeAll { $0.id == existing.id }
            do {
                try await api.removeTorrentBookmark(id: existing.id)
                Haptics.success()
            } catch {
                bookmarks.insert(existing, at: 0)   // rollback
                errorMessage = error.localizedDescription
                Haptics.error()
            }
        } else {
            do {
                let created = try await api.addTorrentBookmark(torrent)
                if !bookmarks.contains(where: { $0.id == created.id }) {
                    bookmarks.insert(created, at: 0)
                }
                Haptics.success()
            } catch {
                errorMessage = error.localizedDescription
                Haptics.error()
            }
        }
    }
}
