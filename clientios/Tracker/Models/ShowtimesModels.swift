//
//  ShowtimesModels.swift
//  Tracker
//
//  Séances de cinéma (Allociné, via le backend) et cinémas favoris enregistrés.
//  En miroir des DTO du client web / de l'API `/showtimes` et `/favorite-theaters`.
//

import Foundation

/// Une séance d'un film dans un cinéma.
struct Showtime: Decodable, Identifiable, Hashable {
    let id: String
    let iso: String          // horodatage complet "2026-07-18T15:30:00"
    let date: String         // "2026-07-18"
    let time: String         // "15:30"
    let version: String?     // "VO" / "VF" (nil si inconnu)
    let formats: [String]    // IMAX, DOLBY_CINEMA, 4DX, 3D...
    let isPreview: Bool       // avant-première
    let ticketingUrl: String?
}

/// Un film à l'affiche dans un cinéma pour une date, avec ses séances.
struct ShowtimeMovie: Decodable, Hashable {
    let id: Int?
    let title: String
    let poster: String?
    let runtime: String?     // déjà formaté, ex. "2h 53min"
    let genres: [String]
    let url: String?
    let shows: [Showtime]
}

/// Métadonnées d'un cinéma.
struct Theater: Decodable, Hashable {
    let code: String
    let name: String?
    let address: String?
    let postalCode: String?
    let city: String?
    let image: String?

    /// Nom lisible, sinon le code.
    var label: String { name ?? code }
}

/// Programme d'un cinéma pour une journée.
struct TheaterShowtimes: Decodable, Hashable {
    let theater: Theater
    let date: String
    let nextDate: String?
    let movies: [ShowtimeMovie]
}

/// Un cinéma enregistré (code Allociné). Coché ou non (`isActive`) : état mémorisé qui
/// détermine les salles affichées sur la page Séances. Liste plate, sans regroupement.
struct FavoriteTheater: Decodable, Identifiable, Hashable {
    let id: Int
    let code: String
    let isActive: Bool
    let position: Int
}
