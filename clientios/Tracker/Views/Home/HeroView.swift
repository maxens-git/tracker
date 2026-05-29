//
//  HeroView.swift
//  Tracker
//
//  Bannière mise en avant en haut de l'accueil (média vedette des tendances).
//

import SwiftUI

struct HeroView: View {
    let item: TMDBSearchResult

    private let height: CGFloat = 460

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            backdrop
            gradient
            content
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
    }

    private var backdrop: some View {
        // Le conteneur (Color) porte la taille ; l'image est posée en overlay
        // puis clippée, ce qui l'empêche d'imposer sa largeur intrinsèque.
        Color(.secondarySystemBackground)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay {
                AsyncImage(url: TMDBService.backdropURL(item.backdropPath, size: "w1280")) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    }
                }
            }
            .clipped()
    }

    private var gradient: some View {
        LinearGradient(
            colors: [.clear, .black.opacity(0.35), .black.opacity(0.9)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(item.displayTitle)
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
                .lineLimit(2)

            if let year = item.year {
                Text(year)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }

            if let overview = item.overview, !overview.isEmpty {
                Text(overview)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(3)
            }

            NavigationLink(value: MediaRoute(tmdbId: item.id, type: item.mediaType)) {
                Label("Voir la fiche", systemImage: "info.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.white)
                    .foregroundStyle(.black)
                    .clipShape(Capsule())
            }
            .padding(.top, 6)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
