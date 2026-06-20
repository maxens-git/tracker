//
//  DesignSystem.swift
//  Tracker
//
//  Vocabulaire visuel partagé inspiré des maquettes Seance :
//  - polices d'affichage « arrondies » (rappel du grotesque des maquettes web) ;
//  - composants réutilisables (en-tête de section, badge de note, chips) ;
//  - modificateur de carte « cinéma » (surface + filet + coin continu).
//

import SwiftUI

// MARK: - Typographies

extension Font {
    /// Police d'affichage pour les titres : système « arrondi », gras par défaut.
    static func display(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - Carte « cinéma »

private struct CinemaCard: ViewModifier {
    var cornerRadius: CGFloat = 16
    var padding: CGFloat? = nil

    func body(content: Content) -> some View {
        content
            .padding(padding ?? 0)
            .background(Color.appSurface,
                        in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.appStroke, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
    }
}

extension View {
    /// Pose le contenu sur une surface de carte (fond + filet + coin continu + ombre douce).
    /// Passer `padding:` pour rembourrer le contenu en même temps.
    func cinemaCard(cornerRadius: CGFloat = 16, padding: CGFloat? = nil) -> some View {
        modifier(CinemaCard(cornerRadius: cornerRadius, padding: padding))
    }
}

// MARK: - Chips

/// Étiquette capsule pour un genre / tag (contour discret).
struct TagChip: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 13)
            .padding(.vertical, 6)
            .overlay(Capsule().strokeBorder(Color.appStroke, lineWidth: 1))
    }
}

// MARK: - Apparence des barres système (nav + onglets)

enum AppAppearance {
    /// Applique la police d'affichage « arrondie » aux titres de navigation
    /// (grand titre + titre inline), pour rester cohérent avec le reste de l'UI.
    static func configure() {
        let nav = UINavigationBarAppearance()
        nav.configureWithDefaultBackground()
        if let large = roundedFont(size: 32, weight: .bold) {
            nav.largeTitleTextAttributes = [.font: large]
        }
        if let inline = roundedFont(size: 17, weight: .semibold) {
            nav.titleTextAttributes = [.font: inline]
        }
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
    }

    private static func roundedFont(size: CGFloat, weight: UIFont.Weight) -> UIFont? {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return nil }
        return UIFont(descriptor: descriptor, size: size)
    }
}
