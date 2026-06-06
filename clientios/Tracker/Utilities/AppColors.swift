//
//  AppColors.swift
//  Tracker
//
//  Couleurs adaptatives de l'app. Le fond principal évite le blanc pur / noir pur
//  (trop "bruts") au profit de tons plus doux qui s'adaptent au thème clair/sombre.
//

import SwiftUI

extension Color {
    /// Fond principal des écrans : gris très clair en mode clair, anthracite (et non
    /// noir pur) en mode sombre. Plus doux que `systemBackground`.
    static let appBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1)   // ~#121214
            : UIColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1)   // ~#F5F5F7
    })

    /// Surface des cartes / blocs posés sur `appBackground` (légèrement contrastée).
    static let appSurface = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.13, green: 0.13, blue: 0.15, alpha: 1)   // ~#212126
            : UIColor.white
    })
}
