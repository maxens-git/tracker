//
//  DesignSystem.swift
//  Tracker
//
//  Vocabulaire visuel de l'app, aligné sur les Human Interface Guidelines :
//  - typographie San Francisco via les styles sémantiques (`.title3`, `.body`,
//    `.footnote`…) pour hériter du Dynamic Type ;
//  - couleurs sémantiques système (cf. `AppColors`) → mode clair / sombre gratuit ;
//  - conteneurs qui reprennent le rendu des `List(.insetGrouped)` : carte
//    `secondarySystemGroupedBackground`, coins continus de 12, séparateurs
//    encastrés ;
//  - contrôles standards (`.borderedProminent`, `.bordered`, `Menu`, `Picker`)
//    plutôt que des habillages maison.
//
//  Ces helpers n'existent que pour le contenu qui ne peut pas passer par une
//  `List` (rangées horizontales, en-tête d'une fiche). Partout ailleurs, on
//  utilise directement `List` / `Form`.
//

import SwiftUI

// MARK: - Tokens

/// Rayons d'angle alignés sur ceux du système (cellules groupées ≈ 10-12,
/// grandes surfaces ≈ 16).
enum AppRadius {
    static let small: CGFloat = 8     // vignettes, photogrammes
    static let medium: CGFloat = 12   // cartes, lignes groupées
    static let large: CGFloat = 20    // grandes surfaces (bannière), généreux comme iOS 26
}

// MARK: - Carte pressable

/// Retour au toucher des vignettes : la carte s'enfonce légèrement sous le
/// doigt puis rebondit (le geste des cartes de l'App Store). À utiliser sur
/// les `NavigationLink` de cartes à la place de `.plain`.
struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableCardStyle {
    static var pressableCard: PressableCardStyle { PressableCardStyle() }
}

extension View {
    /// Atténuation subtile des cartes qui entrent / sortent d'une rangée
    /// horizontale : léger fondu + réduction, interpolés avec le défilement.
    func edgeFade() -> some View {
        scrollTransition(.interactive, axis: .horizontal) { content, phase in
            content
                .opacity(phase.isIdentity ? 1 : 0.65)
                .scaleEffect(phase.isIdentity ? 1 : 0.94)
        }
    }
}

// MARK: - En-tête de section

/// Titre de section d'un écran de contenu, avec une action facultative alignée
/// à droite (« Tout voir »), comme l'App Store ou l'app TV.
struct SectionHeader: View {
    let title: String
    var trailingLabel: String? = nil
    var trailingAction: (() -> Void)? = nil

    init(_ title: String,
         trailingLabel: String? = nil,
         trailingAction: (() -> Void)? = nil) {
        self.title = title
        self.trailingLabel = trailingLabel
        self.trailingAction = trailingAction
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            if let trailingLabel {
                Spacer(minLength: 12)
                Button(trailingLabel) { trailingAction?() }
                    .font(.subheadline.weight(.medium))
                    .disabled(trailingAction == nil)
            }
        }
    }
}

// MARK: - Cartes

private struct CardBackground: ViewModifier {
    var cornerRadius: CGFloat = AppRadius.medium
    var padding: CGFloat? = nil

    func body(content: Content) -> some View {
        content
            .padding(padding ?? 0)
            .background(Color.appSurface,
                        in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

extension View {
    /// Pose le contenu sur une carte au rendu d'une cellule de liste groupée.
    /// Passer `padding:` pour rembourrer le contenu en même temps.
    func cardBackground(cornerRadius: CGFloat = AppRadius.medium, padding: CGFloat? = nil) -> some View {
        modifier(CardBackground(cornerRadius: cornerRadius, padding: padding))
    }
}

/// Groupe de lignes dans une seule carte, séparées par des filets encastrés :
/// le rendu d'une section de `List(.insetGrouped)`, utilisable hors `List`.
struct CardGroup<Content: View>: View {
    var cornerRadius: CGFloat = AppRadius.medium
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .cardBackground(cornerRadius: cornerRadius)
    }
}

/// Séparateur entre deux lignes d'un `CardGroup` (encastré comme dans une liste).
struct RowDivider: View {
    var leadingInset: CGFloat = 16

    var body: some View {
        Divider()
            .padding(.leading, leadingInset)
    }
}

// MARK: - Étiquettes

/// Étiquette capsule pour un genre / tag, dans le gris de remplissage système.
struct TagChip: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.subheadline)
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.tertiarySystemFill), in: .capsule)
    }
}

// MARK: - Badge lecture

/// Bouton lecture posé sur un photogramme : pastille de verre Liquid Glass,
/// glyphe blanc — partagé entre « En cours » et les bandes-annonces.
struct GlassPlayBadge: View {
    var body: some View {
        Image(systemName: "play.fill")
            .font(.subheadline)
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .glassEffect(.regular, in: .circle)
            .environment(\.colorScheme, .dark)
    }
}

// MARK: - Jauge de progression

/// Fine capsule de progression posée au bas d'une vignette (comme l'app TV) :
/// à encastrer avec un peu de marge pour un rendu flottant et élégant.
///
/// Le fond sombre par défaut est fait pour reposer sur une image ; sur une carte,
/// passer `track: Color(.tertiarySystemFill)`.
struct ProgressStripe: View {
    let progress: Double
    var height: CGFloat = 4
    var tint: Color = .white
    var track: Color = .black.opacity(0.35)

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule()
                    .fill(tint)
                    // Jamais plus étroite que sa hauteur : la capsule reste ronde.
                    .frame(width: max(geo.size.width * min(max(progress, 0), 1), height))
            }
        }
        .frame(height: height)
    }
}
