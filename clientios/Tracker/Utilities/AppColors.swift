//
//  AppColors.swift
//  Tracker
//
//  Palette "cinéma" inspirée des maquettes Seance : fond chaud sombre, accent
//  doré, vert pour « vu / progression ». Les tokens sont adaptatifs clair/sombre
//  pour conserver le support des deux thèmes.
//

import SwiftUI

extension Color {
    /// Fond principal des écrans. Sombre : brun-noir chaud (#141210, façon Seance).
    /// Clair : blanc cassé chaud (et non gris froid) pour rester dans la même famille.
    static let appBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.078, green: 0.071, blue: 0.063, alpha: 1)  // ~#141210
            : UIColor(red: 0.957, green: 0.945, blue: 0.925, alpha: 1)  // ~#F4F1EC
    })

    /// Surface des cartes / blocs posés sur `appBackground`.
    static let appSurface = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.106, green: 0.094, blue: 0.078, alpha: 1)  // ~#1B1814
            : UIColor(red: 1.0, green: 0.996, blue: 0.988, alpha: 1)    // ~#FFFEFC
    })

    /// Filet subtil bordant les cartes (clair sur fond sombre, sombre sur fond clair).
    static let appStroke = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.06)
            : UIColor(white: 0, alpha: 0.07)
    })

    /// Accent doré « cinéma ». Plus profond en clair pour rester lisible sur blanc.
    static let appGold = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.906, green: 0.718, blue: 0.400, alpha: 1)  // ~#E7B766
            : UIColor(red: 0.741, green: 0.529, blue: 0.196, alpha: 1)  // ~#BD8732
    })

    /// Variante plus chaude/profonde du doré, pour les dégradés.
    static let appGoldDeep = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.827, green: 0.604, blue: 0.290, alpha: 1)  // ~#D39A4A
            : UIColor(red: 0.655, green: 0.451, blue: 0.157, alpha: 1)  // ~#A77328
    })

    /// Vert « vu / terminé / progression ».
    static let appGreen = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.510, green: 0.780, blue: 0.604, alpha: 1)  // ~#82C79A
            : UIColor(red: 0.235, green: 0.580, blue: 0.392, alpha: 1)  // ~#3C9464
    })

    /// Dégradé doré utilisé pour les boutons / accents pleins (logo, CTA).
    static var appGoldGradient: LinearGradient {
        LinearGradient(colors: [.appGold, .appGoldDeep],
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
