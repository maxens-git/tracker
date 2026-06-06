//
//  Haptics.swift
//  Tracker
//
//  Retour haptique centralisé pour les actions utilisateur
//  (marquer vu/aimé, ajout à une liste, tap d'une affiche…).
//
//  L'API expose un enum maison `Haptics.Impact` plutôt que les types UIKit :
//  les appelants n'ont ainsi pas besoin d'importer UIKit, requis depuis
//  Xcode 26 pour accéder à un membre d'un module non importé directement.
//

import UIKit

enum Haptics {
    /// Intensité du "tap" d'impact, indépendante d'UIKit côté appelant.
    enum Impact {
        case light, medium, heavy, soft, rigid

        fileprivate var uiStyle: UIImpactFeedbackGenerator.FeedbackStyle {
            switch self {
            case .light:  return .light
            case .medium: return .medium
            case .heavy:  return .heavy
            case .soft:   return .soft
            case .rigid:  return .rigid
            }
        }
    }

    /// Action accomplie avec succès (vu, ajouté à une liste, liste créée…).
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Action échouée.
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    /// Avertissement (suppression…).
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    /// Petit "tap" pour les bascules (like, épisode, saison) et le tap d'une affiche.
    static func impact(_ style: Impact = .medium) {
        UIImpactFeedbackGenerator(style: style.uiStyle).impactOccurred()
    }

    /// Changement de sélection.
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
