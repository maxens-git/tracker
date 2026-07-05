//
//  CacheManager.swift
//  Tracker
//
//  Gestion du cache réseau partagé (`URLCache.shared`).
//

import Foundation

/// Cache disque/mémoire partagé par toute l'app via `URLCache.shared`.
///
/// Il stocke, indexées par URL, les réponses déjà téléchargées : affiches TMDB
/// (octets JPEG chargés par `RemoteImage`/`ImageLoader` sur `URLSession.shared`,
/// dont l'image décodée est ensuite gardée par `ImageCache`), fiches films/séries
/// (`TMDBService`) et appels backend. Comme l'URL d'une affiche contient son
/// chemin et celle d'une fiche contient le `tmdbId`, un média déjà vu est
/// réaffiché depuis le cache sans nouvel appel réseau.
///
/// La capacité par défaut d'iOS est trop faible pour conserver beaucoup
/// d'affiches : on l'agrandit au lancement.
enum CacheManager {
    private static let memoryCapacity = 64 * 1024 * 1024   // 64 Mo en RAM
    private static let diskCapacityBytes = 512 * 1024 * 1024 // 512 Mo sur disque

    /// À appeler une seule fois au démarrage, avant toute requête réseau.
    static func configure() {
        URLCache.shared = URLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacityBytes)
    }

    /// Octets actuellement occupés sur le disque par le cache.
    static var diskUsage: Int { URLCache.shared.currentDiskUsage }

    /// Vide entièrement le cache (affiches + fiches). Tout sera retéléchargé au besoin.
    static func clear() {
        URLCache.shared.removeAllCachedResponses()
    }

    /// Taille lisible par un humain (ex. « 24,3 Mo »).
    static func formatted(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}
