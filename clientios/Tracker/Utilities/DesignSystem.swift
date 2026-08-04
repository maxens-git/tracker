//
//  DesignSystem.swift
//  Tracker
//
//  Vocabulaire visuel partagé : direction éditoriale cinéma (titres serif New
//  York, accent doré, retenue) posée sur le chrome translucide d'iOS 26.
//  - titres d'affichage en serif, corps de texte en San Francisco ;
//  - chrome flottant : panneaux, chips et boutons en verre natif (`.glassEffect`)
//    qui laissent transparaître l'affiche derrière eux ;
//  - accent doré réservé aux actions principales, vert pour « vu / progression » ;
//  - angles largement arrondis (capsules et rectangles continus 14 → 26).
//
//  Le verre remplace les aplats : on évite d'empiler un fond opaque + un filet
//  dessiné à la main, `.glassEffect` fournit déjà la teinte, le flou et le rim.
//  Le raffinement passe par la retenue : pas d'effets superflus.
//

import SwiftUI

// MARK: - Tokens

/// Rayons d'angle harmonisés dans toute l'app (évite le mélange 8/10/12/14/16).
enum AppRadius {
    static let small: CGFloat = 14    // affiches, vignettes, petits blocs
    static let medium: CGFloat = 20   // panneaux de verre, listes groupées
    static let large: CGFloat = 26    // grandes surfaces / feuilles
    static let control: CGFloat = 22  // boutons pleine largeur, contrôles
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

/// Titre de section unifié, avec une action facultative alignée à droite
/// (typiquement « Tout » au-dessus d'une rangée horizontale).
struct SectionHeader: View {
    let title: String
    var size: CGFloat = 21
    var trailingLabel: String? = nil
    var trailingAction: (() -> Void)? = nil

    init(_ title: String,
         size: CGFloat = 21,
         trailingLabel: String? = nil,
         trailingAction: (() -> Void)? = nil) {
        self.title = title
        self.size = size
        self.trailingLabel = trailingLabel
        self.trailingAction = trailingAction
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.display(size))
                .foregroundStyle(.primary)

            if let trailingLabel {
                Spacer(minLength: 12)
                Button(trailingLabel) { trailingAction?() }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
                    .disabled(trailingAction == nil)
            }
        }
    }
}

// MARK: - Panneau de verre

private struct GlassPanel: ViewModifier {
    var cornerRadius: CGFloat = AppRadius.medium
    var padding: CGFloat? = nil

    func body(content: Content) -> some View {
        content
            .padding(padding ?? 0)
            // `.glassEffect` porte à lui seul la teinte, le flou et le filet
            // lumineux du bord : pas de fond opaque ni de stroke ajoutés.
            .glassEffect(.regular,
                         in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

extension View {
    /// Pose le contenu sur un panneau de verre (flou + teinte + rim + coin continu).
    /// Passer `padding:` pour rembourrer le contenu en même temps.
    func glassPanel(cornerRadius: CGFloat = AppRadius.medium, padding: CGFloat? = nil) -> some View {
        modifier(GlassPanel(cornerRadius: cornerRadius, padding: padding))
    }
}

/// Liste groupée « encastrée » : un seul bloc de verre, des lignes séparées par
/// un filet, à la façon des groupes de la maquette (épisodes, résultats).
struct GlassRowGroup<Content: View>: View {
    var cornerRadius: CGFloat = AppRadius.medium
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .glassPanel(cornerRadius: cornerRadius)
    }
}

/// Filet de séparation entre deux lignes d'un `GlassRowGroup`.
struct GlassRowDivider: View {
    var leadingInset: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(Color.appStroke)
            .frame(height: 1)
            .padding(.leading, leadingInset)
    }
}

// MARK: - Chips

/// Étiquette capsule pour un genre / tag (verre discret).
struct TagChip: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            // Aplat + filet plutôt que du verre : ces tags reposent sur le fond
            // uni de la page (rien à réfracter), et le `.glassEffect` y ajoutait
            // une ombre portée boîteuse peu esthétique en thème clair.
            .background(Color.appSurface, in: .capsule)
            .overlay(Capsule().strokeBorder(Color.appStroke, lineWidth: 1))
    }
}

/// Chip de filtre sélectionnable : plein (inversé) quand actif, verre sinon.
struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? Color.appBackground : .primary)
                .padding(.horizontal, 15)
                .padding(.vertical, 8)
                // La sélection est portée par la teinte du verre lui-même :
                // un `background` sous le verre resterait invisible.
                .glassEffect(isSelected ? .regular.tint(Color.appAccent) : .regular,
                             in: .capsule)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Boutons

/// Bouton d'action circulaire en verre (ajout, retour, options…).
struct GlassIconButton: View {
    let systemImage: String
    var size: CGFloat = 44
    var tint: Color? = nil
    var accessibilityLabel: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(tint ?? .primary)
                .frame(width: size, height: size)
                .glassEffect(tint.map { .regular.tint($0.opacity(0.22)) } ?? .regular,
                             in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel ?? systemImage)
    }
}

/// Habillage du CTA principal : capsule dorée pleine, sans halo ni dégradé —
/// l'accent suffit à porter l'action, le relief l'alourdirait.
private struct AccentCTA: ViewModifier {
    var cornerRadius: CGFloat = AppRadius.control

    func body(content: Content) -> some View {
        content
            .font(.system(size: 15, weight: .semibold))
            // Le texte reprend la couleur du fond de page : sombre sur le doré
            // clair du thème sombre, clair sur le doré profond du thème clair.
            .foregroundStyle(Color.appBackground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Color.appAccent,
                        in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

extension View {
    /// Applique le style du bouton d'action principal (accent plein).
    func accentCTA(cornerRadius: CGFloat = AppRadius.control) -> some View {
        modifier(AccentCTA(cornerRadius: cornerRadius))
    }
}

// MARK: - Jauge de progression

/// Fine barre de progression posée au bas d'une vignette (vert « vu » par défaut).
struct ProgressStripe: View {
    let progress: Double
    var height: CGFloat = 4
    var tint: Color = .appGreen

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(.white.opacity(0.22))
                Rectangle()
                    .fill(tint)
                    .frame(width: geo.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: height)
    }
}

// MARK: - Surtitre

/// Surtitre en petites capitales très espacées (« SÉRIE · HBO », « SÉLECTION DU JOUR »).
struct Eyebrow: View {
    let text: String
    var color: Color = .appAccent

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9.5, weight: .heavy))
            .tracking(1.5)
            .foregroundStyle(color)
    }
}

// MARK: - Apparence des barres système (nav + onglets)

enum AppAppearance {
    /// Aligne les titres de navigation sur la typographie d'affichage de l'app
    /// (SF très gras).
    ///
    /// Le fond reste celui du système : la barre est transparente tant que le
    /// contenu est en haut, puis passe au verre dès qu'on défile. Une barre
    /// transparente en permanence laissait le titre se superposer aux cartes
    /// pendant le défilement.
    static func configure() {
        let standard = UINavigationBarAppearance()
        standard.configureWithDefaultBackground()
        applyFonts(to: standard)
        UINavigationBar.appearance().standardAppearance = standard

        let scrollEdge = UINavigationBarAppearance()
        scrollEdge.configureWithTransparentBackground()
        applyFonts(to: scrollEdge)
        UINavigationBar.appearance().scrollEdgeAppearance = scrollEdge
    }

    private static func applyFonts(to appearance: UINavigationBarAppearance) {
        if let large = displayFont(size: 32, weight: .semibold) {
            appearance.largeTitleTextAttributes = [.font: large]
        }
        if let inline = displayFont(size: 17, weight: .semibold) {
            appearance.titleTextAttributes = [.font: inline]
        }
    }

    /// Variante serif (New York) de la police système, comme `Font.display`.
    private static func displayFont(size: CGFloat, weight: UIFont.Weight) -> UIFont? {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.serif) else { return nil }
        return UIFont(descriptor: descriptor, size: size)
    }
}
