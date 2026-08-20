//
//  HeroView.swift
//  Tracker
//
//  Carte « à la une » en tête de l'accueil : image large aux coins arrondis,
//  encastrée dans les marges de l'écran (comme les cartes en vedette de l'App
//  Store ou de l'app TV) plutôt qu'une bannière pleine page qui passe sous la
//  barre d'état. Le titre repose sur un dégradé qui garantit le contraste.
//

import SwiftUI

struct HeroView: View {
    let item: TMDBSearchResult
    @Environment(\.zoomNamespace) private var zoomNamespace

    private var route: MediaRoute { MediaRoute(tmdbId: item.id, type: item.mediaType) }

    var body: some View {
        NavigationLink(value: route) {
            VStack(alignment: .leading, spacing: 0) {
                backdrop
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .overlay(alignment: .bottomLeading) { caption }
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
                    .background {
                        RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                            .fill(Color.appSurface)
                            .shadow(color: .black.opacity(0.22), radius: 14, x: 0, y: 8)
                    }
            }
            .zoomSource(route, in: zoomNamespace)
        }
        .buttonStyle(.pressableCard)
        .accessibilityLabel("\(item.displayTitle), sélection du jour")
    }

    private var backdrop: some View {
        Color.appPlaceholder
            .overlay {
                RemoteImage(url: TMDBService.backdropURL(item.backdropPath, size: "w780")
                    ?? TMDBService.posterURL(item.posterPath, size: "w500")) {
                    Image(systemName: "film")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
            }
            .clipped()
    }

    /// Titre + métadonnées posés sur un dégradé sombre : le texte reste blanc
    /// dans les deux thèmes, comme sur les visuels des apps média d'Apple.
    private var caption: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("À la une")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .kerning(0.8)
                .foregroundStyle(.white.opacity(0.75))
                .padding(.bottom, 2)

            Text(item.displayTitle)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)

            Text(metaLine)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background {
            LinearGradient(colors: [.clear, .black.opacity(0.75)],
                           startPoint: .top, endPoint: .bottom)
                .padding(.top, -80)
        }
    }

    /// « Film · 2024 ».
    private var metaLine: String {
        [item.mediaType.label, item.year]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}
