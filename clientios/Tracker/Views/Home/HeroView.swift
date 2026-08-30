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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var route: MediaRoute { MediaRoute(tmdbId: item.id, type: item.mediaType, source: "hero") }

    var body: some View {
        NavigationLink(value: route) {
            backdrop
                .aspectRatio(heroAspectRatio, contentMode: .fit)
                .overlay { contrastGradient }
                .overlay(alignment: .topLeading) { featuredBadge }
                .overlay(alignment: .bottomLeading) { caption }
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                        .strokeBorder(.white.opacity(0.14), lineWidth: 0.5)
                }
                .background {
                    RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                        .fill(Color.appSurface)
                        .shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 9)
                }
            .zoomSource(route, in: zoomNamespace)
        }
        .buttonStyle(.pressableCard)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Ouvre la fiche du média")
    }

    private var backdrop: some View {
        Color.appPlaceholder
            .overlay {
                RemoteImage(url: TMDBService.backdropURL(item.backdropPath, size: "w1280")
                    ?? TMDBService.posterURL(item.posterPath, size: "w500")) {
                    Image(systemName: "film")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
            }
            .clipped()
    }

    /// Un peu plus de hauteur lorsque Dynamic Type est très grand, afin que le
    /// titre, les métadonnées et l'action ne se chevauchent jamais.
    private var heroAspectRatio: CGFloat {
        if dynamicTypeSize.isAccessibilitySize {
            return horizontalSizeClass == .compact ? 1 : 1.6
        }
        return horizontalSizeClass == .compact ? 4.0 / 3.0 : 2.15
    }

    private var contrastGradient: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.2),
                .init(color: .black.opacity(0.18), location: 0.48),
                .init(color: .black.opacity(0.9), location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom)
    }

    private var featuredBadge: some View {
        Label("À LA UNE", systemImage: "sparkles")
            .font(.caption2.weight(.bold))
            .kerning(0.7)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .glassEffect(.regular, in: .capsule)
            .environment(\.colorScheme, .dark)
            .padding(14)
    }

    /// Titre + métadonnées posés sur un dégradé sombre : le texte reste blanc
    /// dans les deux thèmes, comme sur les visuels des apps média d'Apple.
    private var caption: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(item.displayTitle)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(2)

            HStack(spacing: 8) {
                if !metaLine.isEmpty {
                    Text(metaLine)
                }
                if let rating {
                    Label(rating, systemImage: "star.fill")
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(.yellow)
                }
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(.white.opacity(0.86))

            if !dynamicTypeSize.isAccessibilitySize,
               let overview = item.overview, !overview.isEmpty {
                Text(overview)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(2)
                    .frame(maxWidth: 620, alignment: .leading)
            }

            HStack(spacing: 6) {
                Text("Voir la fiche")
                Image(systemName: "arrow.right")
                    .accessibilityHidden(true)
            }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(.white.opacity(0.16), in: .capsule)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
    }

    /// « Film · 2024 ».
    private var metaLine: String {
        [item.mediaType.label, item.year]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private var rating: String? {
        guard let vote = item.voteAverage, vote > 0 else { return nil }
        return vote.formatted(.number.precision(.fractionLength(1)))
    }

    private var accessibilityLabel: String {
        [item.displayTitle, metaLine, rating.map { "note \($0) sur 10" }]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}
