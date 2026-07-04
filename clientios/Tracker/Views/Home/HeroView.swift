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
        // Ramp progressif (plusieurs paliers) plutôt qu'une coupure nette :
        // l'image se fond en douceur vers le bas où repose le texte.
        LinearGradient(
            colors: [.clear, .black.opacity(0.2), .black.opacity(0.55), .black.opacity(0.85)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(item.displayTitle)
                .font(.display(34))
                .foregroundStyle(.white)
                .lineLimit(2)
                .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 2)

            if let year = item.year {
                Text(year)
                    .font(.footnote.weight(.semibold))
                    .tracking(0.5)
                    .foregroundStyle(.white.opacity(0.8))
            }

            if let overview = item.overview, !overview.isEmpty {
                Text(overview)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(2)
            }

            NavigationLink(value: MediaRoute(tmdbId: item.id, type: item.mediaType)) {
                Text("Voir la fiche")
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Color.appGold, in: Capsule())
                    .foregroundStyle(.black)
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
