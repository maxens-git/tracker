//
//  AppColors.swift
//  Tracker
//
//  Jetons de couleur de l'app : de simples alias sur les couleurs sémantiques
//  d'UIKit, pour que l'app suive automatiquement le mode clair / sombre, le
//  contraste élevé et la teinte système (asset `AccentColor`).
//
//  Règle : aucune couleur « en dur » dans les vues. Un fond de page passe par
//  `appBackground`, une carte posée dessus par `appSurface`, un filet par
//  `appStroke` — exactement les valeurs qu'utilisent les `List` d'iOS.
//

import SwiftUI

extension Color {
    /// Fond des écrans structurés en listes / cartes (comme `List(.insetGrouped)`).
    static let appBackground = Color(.systemGroupedBackground)

    /// Fond d'une carte ou d'une ligne posée sur `appBackground`.
    static let appSurface = Color(.secondarySystemGroupedBackground)

    /// Fond neutre des vignettes (affiche en cours de chargement, placeholder).
    static let appPlaceholder = Color(.secondarySystemFill)

    /// Filet de séparation, identique aux séparateurs des listes système.
    static let appStroke = Color(.separator)

    /// Vert sémantique « vu / terminé / progression ».
    static let appGreen = Color.green
}
