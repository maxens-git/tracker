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
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.bottom, 12)
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .overlay(alignment: .topTrailing) { badge }
        .overlay(alignment: .bottom) { progressBar }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
    }

    private var backdrop: some View {
        Color(.secondarySystemBackground)
            .overlay {
                if let url = TMDBService.backdropURL(item.backdropPath, size: "w780")
                    ?? TMDBService.posterURL(item.posterPath, size: "w500") {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image): image.resizable().scaledToFill()
                        case .failure: placeholderIcon
                        case .empty: ProgressView()
                        @unknown default: placeholderIcon
                        }
                    }
                } else {
                    placeholderIcon
                }
            }
            .clipped()
    }

    /// Badge du prochain épisode (ex. « S2 · E5 »).
    private var badge: some View {
        Text(item.nextLabel)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(.black.opacity(0.65), in: Capsule())
            .padding(8)
    }

    @ViewBuilder
    private var progressBar: some View {
        if let progress = item.progress {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(.black.opacity(0.45))
                    Rectangle()
                        .fill(Color(red: 0.13, green: 0.77, blue: 0.37))
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
