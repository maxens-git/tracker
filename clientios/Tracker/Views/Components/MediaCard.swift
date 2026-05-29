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
        VStack(alignment: .leading, spacing: 6) {
            PosterImage(path: posterPath)
                .aspectRatio(2.0 / 3.0, contentMode: .fit)

            Text(title)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)
                .foregroundStyle(.primary)

            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
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
