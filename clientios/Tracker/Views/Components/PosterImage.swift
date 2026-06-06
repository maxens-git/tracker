//
//  PosterImage.swift
//  Tracker
//
//  Affiche une affiche TMDB avec placeholder et chargement asynchrone.
//  La vue impose toujours une boîte au ratio 2:3 (avec découpe) pour que
//  toutes les affiches aient exactement la même taille dans une grille.
//

import SwiftUI

struct PosterImage: View {
    let path: String?
    var size: String = "w342"

    var body: some View {
        // Color (greedy) + aspectRatio = boîte 2:3 stricte calée sur la largeur
        // proposée. L'image remplit cette boîte (scaledToFill) et le surplus est
        // découpé par le clipShape : toutes les affiches ont la même taille.
        Color(.secondarySystemBackground)
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .overlay {
                if let url = TMDBService.posterURL(path, size: size) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .failure:
                            placeholderIcon
                        case .empty:
                            ProgressView()
                        @unknown default:
                            placeholderIcon
                        }
                    }
                } else {
                    placeholderIcon
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var placeholderIcon: some View {
        Image(systemName: "film")
            .font(.title)
            .foregroundStyle(.secondary)
    }
}
