//
//  ContinueCard.swift
//  Tracker
//
//  Carte paysage de la section « Reprendre » : image backdrop, titre, badge du
//  prochain épisode et fine barre de progression verte.
//

import SwiftUI

struct ContinueCard: View {
    let item: ContinueWatchingItem

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            backdrop

            // Dégradé sombre pour garder le titre lisible sur l'image.
            LinearGradient(
                colors: [.black.opacity(0.85), .clear],
                startPoint: .bottom,
                endPoint: .center
            )

            Text(item.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .overlay(alignment: .topTrailing) { badge }
        .overlay(alignment: .bottom) { progressBar }
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous))
        // Ombre posée sur une forme opaque en arrière-plan (et non sur le contenu
        // composité) pour éviter une rasterisation hors-écran par frame de scroll.
        .background {
            RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 5)
        }
    }

    private var backdrop: some View {
        Color(.secondarySystemBackground)
            .overlay {
                RemoteImage(url: TMDBService.backdropURL(item.backdropPath, size: "w780")
                    ?? TMDBService.posterURL(item.posterPath, size: "w500")) {
                    placeholderIcon
                }
            }
            .clipped()
    }

    /// Badge du prochain épisode (ex. « S2 · E5 »).
    private var badge: some View {
        Text(item.nextLabel)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial, in: Capsule())
            .environment(\.colorScheme, .dark)
            .padding(8)
    }

    @ViewBuilder
    private var progressBar: some View {
        if let progress = item.progress {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(.black.opacity(0.45))
                    Rectangle()
                        .fill(Color.appGreen)
                        .frame(width: geo.size.width * CGFloat(progress))
                }
            }
            .frame(height: 4)
        }
    }

    private var placeholderIcon: some View {
        Image(systemName: "tv")
            .font(.title)
            .foregroundStyle(.secondary)
    }
}
