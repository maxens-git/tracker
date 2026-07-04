//
//  SearchHistoryStore.swift
//  Tracker
//
//  Historique de recherche local (par appareil), persisté dans UserDefaults.
//  Volontairement côté client : la recherche interroge TMDB depuis le frontend,
//  aucune donnée sensible, pas besoin d'aller-retour serveur.
//

import Foundation

@Observable
@MainActor
final class SearchHistoryStore {
    /// Requêtes récentes, de la plus récente à la plus ancienne.
    private(set) var entries: [String] = []

    private let key = "searchHistory"
    private let maxEntries = 12
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        entries = defaults.stringArray(forKey: key) ?? []
    }

    /// Enregistre une requête. Ignore les chaînes trop courtes et « replie » la frappe
    /// incrémentale : taper « Dune » ne laisse que « Dune » (pas « D », « Du », « Dun »).
    func record(_ raw: String) {
        let query = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else { return }

        let lowered = query.lowercased()
        var next = entries.filter { existing in
            let a = existing.lowercased()
            return !(a == lowered || a.hasPrefix(lowered) || lowered.hasPrefix(a))
        }
        next.insert(query, at: 0)
        entries = Array(next.prefix(maxEntries))
        persist()
    }

    func remove(_ entry: String) {
        entries.removeAll { $0 == entry }
        persist()
    }

    func clear() {
        entries = []
        persist()
    }

    private func persist() {
        defaults.set(entries, forKey: key)
    }
}
