//
//  MediaType.swift
//  Tracker
//

import Foundation

/// Type de média manipulé par l'app. La valeur brute correspond à ce
/// qu'attend le backend et l'API TMDB ("movie" / "tv").
enum MediaType: String, Codable, CaseIterable, Identifiable, Hashable {
    case movie
    case tv

    var id: String { rawValue }

    /// Libellé affiché dans l'UI.
    var label: String {
        switch self {
        case .movie: return "Film"
        case .tv: return "Série"
        }
    }

    /// Nom du symbole SF Symbols associé.
    var symbol: String {
        switch self {
        case .movie: return "film"
        case .tv: return "tv"
        }
    }
}
