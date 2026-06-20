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
    /// Affiche un badge « VU » en haut de l'affiche quand le média est déjà vu.
    var seen: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PosterImage(path: posterPath)
                .aspectRatio(2.0 / 3.0, contentMode: .fit)
                .overlay(alignment: .topTrailing) {
                    if seen { seenBadge }
                }
                // Ombre douce pour donner du relief aux affiches.
                .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)

            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
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

    /// Pastille « VU » (accent) posée en haut à droite de l'affiche.
    private var seenBadge: some View {
        Text("VU")
            .font(.system(size: 10, weight: .heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.accentColor))
            .padding(6)
    }
}

/// Grille adaptative réutilisée par Home / Recherche / Détail de liste.
struct MediaGrid<Content: View>: View {
    let columns = [GridItem(.adaptive(minimum: 110), spacing: 16)]
    /// Espacement vertical entre les rangées. Par défaut 20 ; réduit dans le
    /// détail d'une liste où les vignettes sont plus denses.
    var spacing: CGFloat = 20
    @ViewBuilder let content: () -> Content

    var body: some View {
        LazyVGrid(columns: columns, spacing: spacing) {
            content()
        }
        .padding(.horizontal)
    }
}
