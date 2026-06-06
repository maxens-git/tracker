//
//  Haptics.swift
//  Tracker
//
//  Retour haptique centralisé pour les actions utilisateur
//  (marquer vu/aimé, ajout à une liste, etc.).
//

import UIKit

enum Haptics {
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

    /// Petit "tap" pour les bascules (like, épisode, saison).
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    /// Changement de sélection.
    static func selection() {
        UISelectionFeedbackGenerator().selectionOccurred()
    }
}
