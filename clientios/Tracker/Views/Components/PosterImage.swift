//
//  PosterImage.swift
//  Tracker
//
//  Affiche une affiche TMDB avec placeholder et chargement asynchrone.
//

import SwiftUI

struct PosterImage: View {
    let path: String?
    var size: String = "w342"

    var body: some View {
        Group {
            if let url = TMDBService.posterURL(path, size: size) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        placeholder
                    case .empty:
                        placeholder.overlay(ProgressView())
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                // Pas d'affiche disponible : on affiche le placeholder sans spinner
                // (sinon AsyncImage(url: nil) reste bloqué en .empty → loading infini).
                placeholder
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var placeholder: some View {
        Rectangle()
            .fill(Color(.secondarySystemBackground))
            .overlay(
                Image(systemName: "film")
                    .font(.title)
                    .foregroundStyle(.secondary)
            )
    }
}
