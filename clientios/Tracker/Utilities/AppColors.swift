//
//  AppColors.swift
//  Tracker
//
//  Palette "cinéma" : fond chaud sombre, accent doré, vert pour « vu /
//  progression ». L'app est verrouillée en mode sombre (cf. `TrackerApp`),
//  les tokens sont donc des couleurs fixes.
//
//  Depuis le passage au chrome Liquid Glass, les surfaces des cartes ne sont
//  plus des aplats mais du verre (`.glassEffect`) : `appSurface` ne sert donc
//  plus qu'aux fonds de secours (placeholder d'affiche, vignette en cours de
//  chargement) et `appStroke` aux filets de séparation.
//

import SwiftUI

extension Color {
    /// Fond principal des écrans : brun-noir chaud (#141210, façon Seance).
    static let appBackground = Color(red: 0.078, green: 0.071, blue: 0.063)  // ~#141210

    /// Surface opaque de secours, posée sous les images le temps du chargement.
    static let appSurface = Color(red: 0.106, green: 0.094, blue: 0.078)  // ~#1B1814

    /// Filet subtil bordant les cartes (clair sur fond sombre).
    static let appStroke = Color(white: 1, opacity: 0.06)

    /// Accent doré « cinéma ».
    static let appAccent = Color(red: 0.906, green: 0.718, blue: 0.400)  // ~#E7B766

    /// Variante plus chaude/profonde du doré, pour les dégradés.
    static let appAccentSoft = Color(red: 0.827, green: 0.604, blue: 0.290)  // ~#D39A4A

    /// Vert « vu / terminé / progression ».
    static let appGreen = Color(red: 0.510, green: 0.780, blue: 0.604)  // ~#82C79A

    /// Dégradé doré utilisé pour les boutons / accents pleins (logo, CTA).
    static var appAccentGradient: LinearGradient {
        LinearGradient(colors: [.appAccent, .appAccentSoft],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Initialiseur hexadécimal pratique (0xRRGGBB).
    init(hex: UInt, alpha: Double = 1) {
        self.init(.sRGB,
                  red:   Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue:  Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}
