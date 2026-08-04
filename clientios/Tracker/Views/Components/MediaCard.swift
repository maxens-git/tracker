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
                // Ombre discrète : suggère le relief de l'affiche sans l'alourdir.
                // Posée sur une forme opaque en arrière-plan (et non sur le contenu
                // composité) pour que SwiftUI n'ait pas à rasteriser l'affiche
                // hors-écran à chaque frame de défilement.
                .background {
                    RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                        .fill(Color.appSurface)
                        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 5)
                }

            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(.primary)

            Text(subtitle ?? " ")
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(.secondary)
        }
        // La carte se cale en haut de sa cellule : l'affiche reste alignée d'une
        // vignette à l'autre, et l'espace libre des titres courts passe en bas
        // (plutôt qu'entre le titre et l'année).
        .frame(maxHeight: .infinity, alignment: .top)
    }

    /// Pastille « vu » posée en haut à droite de l'affiche : simple coche verte
    /// (couleur sémantique « vu / terminé » de l'app), plus discrète qu'un badge texte.
    private var seenBadge: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .padding(5)
            .background(Circle().fill(Color.appGreen))
            .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1))
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
