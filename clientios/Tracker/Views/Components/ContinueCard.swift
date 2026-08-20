//
//  ContinueCard.swift
//  Tracker
//
//  Carte paysage de la section « En cours » : photogramme 16:9, bouton lecture
//  en matériau translucide, barre de progression au bas de la vignette, puis
//  titre et prochain épisode dessous (comme la rangée « À suivre » de l'app TV).
//

import SwiftUI

struct ContinueCard: View {
    let item: ContinueWatchingItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            thumbnail

            Text(item.title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(item.nextLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var thumbnail: some View {
        backdrop
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .overlay { playBadge }
            .overlay(alignment: .bottom) { progressBar }
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
            .background {
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .fill(Color.appSurface)
                    .shadow(color: .black.opacity(0.16), radius: 8, x: 0, y: 4)
            }
    }

    private var backdrop: some View {
        Color.appPlaceholder
            .overlay {
                RemoteImage(url: TMDBService.backdropURL(item.backdropPath, size: "w780")
                    ?? TMDBService.posterURL(item.posterPath, size: "w500")) {
                    placeholderIcon
                }
            }
            .clipped()
    }

    private var playBadge: some View {
        GlassPlayBadge()
    }

    @ViewBuilder
    private var progressBar: some View {
        if let progress = item.progress {
            ProgressStripe(progress: progress)
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
                .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
        }
    }

    private var placeholderIcon: some View {
        Image(systemName: "tv")
            .font(.title2)
            .foregroundStyle(.secondary)
    }
}
