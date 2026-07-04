//
//  TorrentModels.swift
//  Tracker
//
//  Modèles de la recherche torrents / débridage (backend Prowlarr + AllDebrid).
//  Les clés JSON du backend sont en camelCase, alignées sur les noms de propriétés.
//

import Foundation

/// Un indexeur torrent configuré dans Prowlarr.
struct Indexer: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
}

/// Une catégorie de recherche Prowlarr (ex. 2000 = Films, 5000 = Séries).
struct TorrentCategory: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
}

/// Un résultat de recherche torrent (protocole torrent + magnet disponible).
struct TorrentResult: Codable, Hashable {
    let title: String
    let size: Int64
    let seeders: Int
    let leechers: Int
    let indexer: String
    let magnetUrl: String
}

/// Un fichier d'un torrent débridé. `link` est le lien AllDebrid « verrouillé »,
/// à passer à `/unlock` pour obtenir le lien de téléchargement direct.
struct DebridFile: Codable, Hashable {
    let filename: String
    let size: Int64
    let link: String
}

/// Résultat d'un débridage : la liste des fichiers (sans lien direct encore généré).
struct DebridResult: Codable {
    let files: [DebridFile]
}

/// Résultat d'un unlock : le lien de téléchargement direct.
struct UnlockResult: Codable {
    let directLink: String
}

// MARK: - Formatage

enum ByteFormat {
    /// Taille lisible façon web ("1,2 Go") ; « — » si inconnue.
    static func string(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "—" }
        let units = ["o", "Ko", "Mo", "Go", "To"]
        var value = Double(bytes)
        var unit = 0
        while value >= 1024 && unit < units.count - 1 {
            value /= 1024
            unit += 1
        }
        let decimals = (value >= 10 || unit == 0) ? 0 : 1
        return String(format: "%.\(decimals)f %@", value, units[unit])
    }
}

extension String {
    /// Extension de fichier en majuscules (ex. « MKV »), vide si aucune.
    var fileExtensionUppercased: String {
        guard let dot = lastIndex(of: "."), dot < index(before: endIndex) else { return "" }
        return String(self[index(after: dot)...]).uppercased()
    }
}
