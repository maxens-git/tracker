//
//  DesignSystem.swift
//  Tracker
//
//  Vocabulaire visuel partagé, direction « éditoriale cinéma » :
//  - titres d'affichage en serif (New York) pour un rendu magazine élégant ;
//  - corps de texte en San Francisco système (lisible, sobre) ;
//  - composants réutilisables (en-tête de section, badge de note, chips) ;
//  - carte « cinéma » (surface + filet + coin continu + ombre discrète).
//
//  Le raffinement passe par la retenue : ombres légères, angles cohérents,
//  hiérarchie typographique claire — pas d'effets superflus.
//

import SwiftUI

// MARK: - Tokens

/// Rayons d'angle harmonisés dans toute l'app (évite le mélange 8/10/12/14/16).
enum AppRadius {
    static let small: CGFloat = 12   // affiches, vignettes, petits blocs
    static let medium: CGFloat = 16  // cartes de contenu
    static let large: CGFloat = 20   // grandes surfaces / feuilles
}

// MARK: - Typographies

extension Font {
    /// Police d'affichage des titres : serif « New York », pour un rendu éditorial
    /// et cinéma. Poids semibold par défaut (élégant, moins massif que bold).
    static func display(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

// MARK: - En-tête de section

/// Titre de section unifié (serif). Un seul style dans toute l'app pour une
/// hiérarchie cohérente au-dessus des rangées de contenu.
struct SectionHeader: View {
    let title: String
    var size: CGFloat = 21

    init(_ title: String, size: CGFloat = 21) {
        self.title = title
        self.size = size
    }

    var body: some View {
        Text(title)
            .font(.display(size))
            .foregroundStyle(.primary)
    }
}

// MARK: - Carte « cinéma »

private struct CinemaCard: ViewModifier {
    var cornerRadius: CGFloat = AppRadius.medium
    var padding: CGFloat? = nil

    func body(content: Content) -> some View {
        content
            .padding(padding ?? 0)
            // Fond + ombre portés par une même forme opaque : SwiftUI calcule
            // l'ombre à partir de la forme (analytique, gratuit) au lieu de
            // rasteriser tout le contenu de la carte hors-écran à chaque frame
            // de défilement — c'était la principale cause des saccades.
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.appSurface)
                    // Ombre volontairement très discrète : la carte tient par son
                    // filet, pas par un relief marqué (rendu plus « posé »).
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
            }
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.appStroke, lineWidth: 1)
            )
    }
}

extension View {
    /// Pose le contenu sur une surface de carte (fond + filet + coin continu + ombre douce).
    /// Passer `padding:` pour rembourrer le contenu en même temps.
    func cinemaCard(cornerRadius: CGFloat = AppRadius.medium, padding: CGFloat? = nil) -> some View {
        modifier(CinemaCard(cornerRadius: cornerRadius, padding: padding))
    }
}

// MARK: - Chips

/// Étiquette capsule pour un genre / tag (contour discret).
struct TagChip: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 13)
            .padding(.vertical, 6)
            .overlay(Capsule().strokeBorder(Color.appStroke, lineWidth: 1))
    }
}

// MARK: - Apparence des barres système (nav + onglets)

enum AppAppearance {
    /// Applique la police d'affichage serif aux titres de navigation
    /// (grand titre + titre inline), pour rester cohérent avec le reste de l'UI.
    static func configure() {
        let nav = UINavigationBarAppearance()
        nav.configureWithDefaultBackground()
        if let large = displayFont(size: 32, weight: .semibold) {
            nav.largeTitleTextAttributes = [.font: large]
        }
        if let inline = displayFont(size: 17, weight: .semibold) {
            nav.titleTextAttributes = [.font: inline]
        }
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
    }

    private static func displayFont(size: CGFloat, weight: UIFont.Weight) -> UIFont? {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.serif) else { return nil }
        return UIFont(descriptor: descriptor, size: size)
    }
}
