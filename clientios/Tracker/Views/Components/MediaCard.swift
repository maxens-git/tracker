//
//  MediaCard.swift
//  Tracker
//
//  Vignette d'un média (affiche + titre) utilisée dans les grilles et les
//  rangées horizontales, dans l'esprit des collections de l'app TV : affiche
//  aux coins arrondis, titre en `footnote`, complément en `caption` secondaire.
//

import SwiftUI

struct MediaCard: View {
    let posterPath: String?
    let title: String
    var subtitle: String?
    /// Coche « vu » posée sur l'affiche quand le média est déjà vu.
    var seen: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            PosterImage(path: posterPath)
                .aspectRatio(2.0 / 3.0, contentMode: .fit)
                .overlay(alignment: .topTrailing) {
                    if seen { seenBadge }
                }
                // Ombre posée sur une forme opaque en arrière-plan (et non sur
                // le contenu composité) : le relief sans rasterisation par frame.
                .background {
                    RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                        .fill(Color.appSurface)
                        .shadow(color: .black.opacity(0.16), radius: 8, x: 0, y: 4)
                }

            Text(title)
                .font(.footnote)
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
        // vignette à l'autre, et l'espace libre des titres courts passe en bas.
        .frame(maxHeight: .infinity, alignment: .top)
    }

    /// Pastille « vu » : coche blanche sur pastille verte, posée sur l'affiche.
    private var seenBadge: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.body)
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, Color.appGreen)
            .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
            .padding(6)
    }
}

/// Grille adaptative réutilisée par Home / Recherche / Détail de liste.
struct MediaGrid<Content: View>: View {
    let columns = [GridItem(.adaptive(minimum: 110), spacing: 16)]
    /// Espacement vertical entre les rangées.
    var spacing: CGFloat = 20
    @ViewBuilder let content: () -> Content

    var body: some View {
        LazyVGrid(columns: columns, spacing: spacing) {
            content()
        }
        .padding(.horizontal)
    }
}
