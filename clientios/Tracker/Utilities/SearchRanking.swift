//
//  SearchRanking.swift
//  Tracker
//
//  Classement des résultats de recherche par pertinence réelle.
//
//  TMDB trie /search/multi par une popularité pondérée : chercher « dune »
//  remontait des documentaires obscurs avant le film, et « alien » plaçait des
//  suites mineures devant l'original. On rejoue donc le tri côté client à
//  partir de la correspondance du titre, la popularité ne servant qu'à
//  départager deux titres qui matchent aussi bien.
//
//  Les paliers de correspondance sont espacés d'au moins 10 points, alors que
//  les bonus cumulés (popularité, votes) ne peuvent bouger un résultat que de 7
//  au maximum : un titre populaire ne peut jamais doubler un titre qui
//  correspond mieux à la requête. Seule la pénalité « fiche fantôme » franchit
//  délibérément un palier.
//
//  On ne descend jamais un résultat en dessous de ce que sa position TMDB
//  justifie (cf. `implicitScore`) : TMDB matche aussi sur les titres alternatifs
//  qu'il ne renvoie pas. Chercher « spirited away » avec l'app en français
//  remonte « Le Voyage de Chihiro », dont ni le titre localisé ni le titre
//  d'origine (japonais) ne contiennent la requête — le classement ne peut donc
//  que promouvoir sur correspondance visible, jamais enterrer.
//
//  Cette logique est dupliquée à l'identique dans clientweb
//  (`src/shared/services/search-ranking.ts`) : toute correction ici doit y être
//  reportée, sans quoi les deux clients ne classeraient plus pareil.
//

import Foundation

enum SearchRanking {

    // MARK: - Normalisation

    /// Minuscules, sans accents, sans ponctuation, espaces normalisés.
    /// « Le Voyage de Chihiro : L'Édition » → « le voyage de chihiro l edition ».
    static func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive],
                                  locale: Locale(identifier: "en_US_POSIX"))
        let cleaned = folded.map { $0.isLetter || $0.isNumber ? $0 : " " }
        return String(cleaned).split(separator: " ").joined(separator: " ")
    }

    // MARK: - Correspondance d'un titre

    /// Score de correspondance d'un titre avec la requête, de 0 (rien) à 1 (exact).
    static func titleScore(_ title: String, query: String) -> Double {
        let candidate = normalize(title)
        let needle = normalize(query)
        guard !candidate.isEmpty, !needle.isEmpty else { return 0 }

        if candidate == needle { return 1.0 }
        // « dune » doit remonter « Dune » puis « Dune : Deuxième partie » avant
        // « Les Enfants de Dune ».
        if candidate.hasPrefix(needle + " ") { return 0.85 }
        // Préfixe en cours de frappe : « dun » → « Dune ».
        if candidate.hasPrefix(needle) { return 0.75 }
        // La requête apparaît comme mot entier ailleurs dans le titre.
        if candidate.contains(" " + needle + " ") || candidate.hasSuffix(" " + needle) { return 0.65 }
        if candidate.contains(needle) { return 0.5 }

        let words = candidate.split(separator: " ").map(String.init)
        let needleWords = needle.split(separator: " ").map(String.init)
        guard !needleWords.isEmpty else { return 0 }
        let wordSet = Set(words)

        // Tous les mots de la requête sont présents, mais dispersés.
        let exactWordMatches = needleWords.filter { wordSet.contains($0) }.count
        if exactWordMatches == needleWords.count { return 0.4 }
        if exactWordMatches > 0 {
            return 0.25 * Double(exactWordMatches) / Double(needleWords.count)
        }

        // Dernier recours : un mot de la requête amorce un mot du titre
        // (« chihi » → « chihiro »).
        let prefixMatches = needleWords.filter { needleWord in
            words.contains { $0.hasPrefix(needleWord) }
        }.count
        guard prefixMatches > 0 else { return 0 }
        return 0.15 * Double(prefixMatches) / Double(needleWords.count)
    }

    // MARK: - Score global

    /// Correspondance implicite déduite du rang TMDB : ce que la position d'un
    /// résultat garantit, même quand aucun titre visible ne matche (TMDB a
    /// reconnu un titre alternatif qu'il ne nous renvoie pas). Décroît de 0,8 en
    /// tête à 0 au-delà du 24ᵉ résultat.
    static func implicitScore(tmdbIndex: Int) -> Double {
        max(0, 0.8 * (1 - Double(tmdbIndex) / 24))
    }

    /// Score d'un résultat : palier de correspondance (×100) puis départage.
    /// `tmdbIndex` est la position d'origine dans la réponse TMDB.
    static func score(titles: [String],
                      query: String,
                      tmdbIndex: Int,
                      popularity: Double,
                      voteCount: Int,
                      hasPoster: Bool) -> Double {
        // Le titre localisé et le titre d'origine sont testés tous les deux :
        // on garde le meilleur des deux, sans jamais passer sous le plancher
        // que la position TMDB justifie.
        let own = titles.map { titleScore($0, query: query) }.max() ?? 0
        let best = max(own, implicitScore(tmdbIndex: tmdbIndex))

        // Échelles logarithmiques : au-delà de quelques milliers de votes, la
        // différence ne dit plus rien de la pertinence.
        let popularityBoost = min(log10(max(popularity, 0) + 1) / 3, 1)
        let votesBoost = min(log10(Double(max(voteCount, 0)) + 1) / 5, 1)

        let base = best * 100 + popularityBoost * 4 + votesBoost * 3 - (hasPoster ? 0 : 2)

        // Ni affiche ni vote : fiche fantôme (doublon vide, brouillon jamais
        // rempli). Chercher « le parrain » en remontait une, titre exact donc au
        // meilleur palier possible, devant les vrais films. On la plafonne sous
        // le palier des correspondances faibles plutôt que de lui retrancher un
        // malus : rien d'inaffichable ne doit passer devant un vrai résultat.
        guard hasPoster || voteCount > 0 else { return min(base, ghostCeiling) }
        return base
    }

    /// Plafond appliqué aux fiches sans affiche ni vote (sous le palier 0,4).
    private static let ghostCeiling: Double = 30

    // MARK: - Classement d'une liste de résultats

    /// Un résultat et son score, avec sa position TMDB d'origine.
    private struct Scored {
        let index: Int
        let item: TMDBSearchResult
        let score: Double
    }

    /// Trie les résultats par pertinence décroissante pour la requête donnée.
    /// L'ordre reçu doit être celui de TMDB : il sert de plancher et de départage.
    static func rank(_ results: [TMDBSearchResult], query: String) -> [TMDBSearchResult] {
        var scored: [Scored] = []
        scored.reserveCapacity(results.count)
        for (index, item) in results.enumerated() {
            scored.append(Scored(index: index,
                                 item: item,
                                 score: score(for: item, query: query, tmdbIndex: index)))
        }
        // Tri stable : à score égal on conserve l'ordre TMDB d'origine.
        return scored
            .sorted { $0.score == $1.score ? $0.index < $1.index : $0.score > $1.score }
            .map(\.item)
    }

    static func score(for result: TMDBSearchResult, query: String, tmdbIndex: Int) -> Double {
        score(titles: result.searchableTitles,
              query: query,
              tmdbIndex: tmdbIndex,
              popularity: result.popularity ?? 0,
              voteCount: result.voteCount ?? 0,
              hasPoster: result.posterPath != nil)
    }

    /// Retire les doublons (même fiche renvoyée par deux pages), premier gardé.
    static func deduplicated(_ results: [TMDBSearchResult]) -> [TMDBSearchResult] {
        var seen = Set<String>()
        return results.filter { seen.insert($0.uniqueKey).inserted }
    }
}
