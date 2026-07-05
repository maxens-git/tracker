//
//  RemoteImage.swift
//  Tracker
//
//  Chargement d'images distantes fluide pour le défilement.
//
//  `AsyncImage` re-télécharge et surtout re-décode le JPEG sur le main thread à
//  chaque réapparition d'une cellule (et affiche un `ProgressView` qui provoque
//  un re-layout) : d'où les saccades régulières en scroll. Ici on garde en
//  mémoire l'image DÉJÀ DÉCODÉE (bitmap prêt à afficher) et on décode hors du
//  main thread, si bien qu'une cellule recyclée réaffiche son image instantanément.
//

import SwiftUI
import UIKit

/// Cache mémoire d'images déjà décodées, indexé par URL.
///
/// `URLCache` (voir `CacheManager`) conserve les octets JPEG ; ce cache-ci
/// conserve le `UIImage` décodé pour éviter de re-décoder à chaque affichage.
final class ImageCache {
    static let shared = ImageCache()

    private let cache: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        cache.countLimit = 400 // nombre d'images décodées gardées en RAM
        return cache
    }()

    private init() {}

    func image(for url: URL) -> UIImage? { cache.object(forKey: url as NSURL) }
    func insert(_ image: UIImage, for url: URL) { cache.setObject(image, forKey: url as NSURL) }
}

/// Charge et décode une image pour une URL, en s'appuyant sur `ImageCache`.
@MainActor
@Observable
final class ImageLoader {
    private(set) var image: UIImage?
    /// Vrai lorsque le chargement s'est terminé sans image (URL invalide / erreur).
    private(set) var failed = false

    private var loadedURL: URL?
    private var task: Task<Void, Never>?

    /// Démarre (ou réutilise) le chargement de `url`. Sûr à appeler plusieurs fois.
    func load(_ url: URL?) {
        guard loadedURL != url else { return }
        loadedURL = url
        task?.cancel()
        failed = false

        guard let url else { image = nil; return }

        // Cache d'images décodées : réaffichage instantané, sans clignotement.
        if let cached = ImageCache.shared.image(for: url) {
            image = cached
            return
        }

        image = nil
        task = Task { [weak self] in
            let decoded = await Self.fetch(url)
            guard !Task.isCancelled else { return }
            if let decoded { ImageCache.shared.insert(decoded, for: url) }
            guard let self, self.loadedURL == url else { return }
            self.image = decoded
            self.failed = decoded == nil
        }
    }

    /// Télécharge (via `URLSession.shared`, donc en profitant du `URLCache` disque)
    /// puis force le décodage hors du main thread avec `byPreparingForDisplay`.
    private static func fetch(_ url: URL) async -> UIImage? {
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data) else { return nil }
        return await image.byPreparingForDisplay() ?? image
    }
}

/// Affiche une image distante en `scaledToFill`, avec un contenu de repli tant
/// qu'aucune image n'est disponible (chargement en cours, URL absente ou échec).
///
/// Pensé pour être posé en `overlay` d'une boîte de fond neutre : pendant le
/// chargement, `RemoteImage` reste transparent (le fond de la boîte reste visible),
/// et n'affiche le `placeholder` qu'en l'absence réelle d'image.
struct RemoteImage<Placeholder: View>: View {
    let url: URL?
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var loader = ImageLoader()

    var body: some View {
        Group {
            if let image = displayImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if url == nil || loader.failed {
                placeholder()
            } else {
                // Chargement en cours : on laisse voir le fond neutre de la boîte.
                Color.clear
            }
        }
        .task(id: url) { loader.load(url) }
    }

    /// Image du loader, ou lecture synchrone du cache pour éviter la frame de vide
    /// lorsqu'une cellule recyclée réaffiche une image déjà décodée.
    private var displayImage: UIImage? {
        if let image = loader.image { return image }
        return url.flatMap { ImageCache.shared.image(for: $0) }
    }
}
