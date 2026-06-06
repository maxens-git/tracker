//
//  MediaCard.swift
//  Tracker
//
//  Vignette d'un média (affiche + titre) utilisée dans les grilles.
//

import SwiftUI

struct MediaCard: View {
    let posterPath: String?
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PosterImage(path: posterPath)
                .aspectRatio(2.0 / 3.0, contentMode: .fit)
                // Ombre douce pour donner du relief aux affiches.
                .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(.primary)

            Text(subtitle ?? " ")
                .font(.caption)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(.secondary)
        }
        // La carte se cale en haut de sa cellule : l'affiche reste alignée d'une
        // vignette à l'autre, et l'espace libre des titres courts passe en bas
        // (plutôt qu'entre le titre et l'année).
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

/// Grille adaptative réutilisée par Home / Recherche / Détail de liste.
struct MediaGrid<Content: View>: View {
    let columns = [GridItem(.adaptive(minimum: 110), spacing: 16)]
    @ViewBuilder let content: () -> Content

    var body: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            content()
        }
        .padding(.horizontal)
    }
}
