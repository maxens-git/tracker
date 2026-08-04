//
//  ContinueCard.swift
//  Tracker
//
//  Carte paysage de la section « En cours » : image backdrop, pastille de
//  lecture en verre au centre, titre sous l'image et fine barre de progression
//  rouge collée au bas de la vignette (cf. maquette Liquid Glass).
//

import SwiftUI

struct ContinueCard: View {
    let item: ContinueWatchingItem

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            thumbnail

            Text(item.title)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(item.nextLabel)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var thumbnail: some View {
        backdrop
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            // Pastille de lecture en verre, façon contrôle flottant.
            .overlay { playBadge }
            .overlay(alignment: .bottom) { progressBar }
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous))
            // Ombre posée sur une forme opaque en arrière-plan (et non sur le contenu
            // composité) pour éviter une rasterisation hors-écran par frame de scroll.
            .background {
                RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                    .fill(Color.appSurface)
                    .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 5)
            }
    }

    private var backdrop: some View {
        Color.appSurface
            .overlay {
                RemoteImage(url: TMDBService.backdropURL(item.backdropPath, size: "w780")
                    ?? TMDBService.posterURL(item.posterPath, size: "w500")) {
                    placeholderIcon
                }
            }
            .clipped()
    }

    private var playBadge: some View {
        Image(systemName: "play.fill")
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 46, height: 46)
            .glassEffect(.regular, in: .circle)
    }

    @ViewBuilder
    private var progressBar: some View {
        if let progress = item.progress {
            ProgressStripe(progress: progress)
        }
    }

    private var placeholderIcon: some View {
        Image(systemName: "tv")
            .font(.title)
            .foregroundStyle(.secondary)
    }
}
