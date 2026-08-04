//
//  HeroView.swift
//  Tracker
//
//  Bannière mise en avant en haut de l'accueil (média vedette des tendances).
//  Direction Liquid Glass : image pleine largeur qui monte jusqu'au haut de
//  l'écran, halo doré, puis fondu vers le fond de page ; le texte et les
//  contrôles en verre flottent par-dessus, sans carte ni cadre.
//

import SwiftUI

struct HeroView: View {
    let item: TMDBSearchResult
    /// Action du bouton secondaire « + » (ajout à la watchlist), facultative.
    var onAdd: (() -> Void)? = nil

    private let height: CGFloat = 540

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            backdrop
            scrim
            content
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
    }

    private var backdrop: some View {
        // Le conteneur (Color) porte la taille ; l'image est posée en overlay
        // puis clippée, ce qui l'empêche d'imposer sa largeur intrinsèque.
        Color.appSurface
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay {
                // `original` : la bannière fait 540 pt de haut en pleine largeur,
                // donc le backdrop 16:9 est fortement agrandi ; w1280 ressort flou.
                RemoteImage(url: TMDBService.backdropURL(item.backdropPath, size: "original")) {
                    Color.clear
                }
            }
            .clipped()
    }

    /// Trois couches : un halo doré diffus en haut à gauche (la « lumière » de la
    /// maquette), un voile sombre qui adosse le texte, puis un fondu discret vers
    /// le fond de page.
    private var scrim: some View {
        ZStack {
            RadialGradient(
                colors: [Color.appAccent.opacity(0.22), .clear],
                center: .init(x: 0.3, y: 0.2),
                startRadius: 0,
                endRadius: height * 0.75
            )
            // Vignette sombre (indépendante du thème) qui adosse le texte blanc :
            // en mode clair, `appBackground` est un crème pâle sur lequel le titre
            // s'effacerait. Elle est posée sur l'image et revient entièrement à
            // `clear` AVANT le fondu de page — sinon le noir résiduel mélangé au
            // crème donnait une bavure grise sale en bas de la bannière.
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.42), location: 0),
                    .init(color: .clear, location: 0.30),
                    .init(color: .black.opacity(0.18), location: 0.58),
                    .init(color: .black.opacity(0.52), location: 0.82),
                    .init(color: .clear, location: 0.90)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            // Fondu de page : l'image se dissout dans le fond crème sur le dernier
            // dixième, là où la vignette est déjà transparente — une transition
            // image → crème propre, sans mélange avec le noir.
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.90),
                    .init(color: Color.appBackground, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "Sélection du jour", color: .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .glassEffect(.regular, in: .capsule)

            Text(item.displayTitle)
                .font(.display(36))
                .foregroundStyle(.white)
                .lineLimit(2)
                .padding(.top, 14)
                .shadow(color: .black.opacity(0.4), radius: 18, x: 0, y: 3)

            Text(metaLine)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.82))
                .padding(.top, 10)

            HStack(spacing: 11) {
                NavigationLink(value: MediaRoute(tmdbId: item.id, type: item.mediaType)) {
                    Label("Voir la fiche", systemImage: "play.fill")
                        .accentCTA()
                }
                .buttonStyle(.plain)

                if let onAdd {
                    Button(action: onAdd) {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 54, height: 52)
                            .glassEffect(.regular,
                                         in: RoundedRectangle(cornerRadius: AppRadius.control,
                                                              style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Ajouter à ma liste")
                }
            }
            .padding(.top, 20)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Ligne de métadonnées façon maquette : « Film · 2024 ».
    private var metaLine: String {
        [item.mediaType.label, item.year]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}
