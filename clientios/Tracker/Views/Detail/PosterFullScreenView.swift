//
//  PosterFullScreenView.swift
//  Tracker
//
//  Affichage plein écran d'une affiche, avec zoom, enregistrement dans la
//  photothèque et partage.
//

import SwiftUI
import Photos

struct PosterFullScreenView: View {
    /// Chemin TMDB de l'affiche (ex. "/abc123.jpg").
    let posterPath: String?

    @Environment(\.dismiss) private var dismiss

    @State private var loadedImage: UIImage?
    @State private var didFail = false

    // Retour utilisateur de l'enregistrement.
    @State private var saveMessage: String?

    private var imageURL: URL? {
        guard let posterPath, !posterPath.isEmpty else { return nil }
        return URL(string: "\(AppConfig.tmdbImageBaseURL)/original\(posterPath)")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let loadedImage {
                    ZoomableImageView(image: loadedImage)
                } else if didFail {
                    placeholder
                } else {
                    ProgressView()
                        .tint(.white)
                }

                if let saveMessage {
                    Text(saveMessage)
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 40)
                        .transition(.opacity)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            Task { await saveToPhotos() }
                        } label: {
                            Label("Enregistrer dans Photos", systemImage: "square.and.arrow.down")
                        }

                        if let loadedImage {
                            ShareLink(item: Image(uiImage: loadedImage),
                                      preview: SharePreview("Affiche", image: Image(uiImage: loadedImage))) {
                                Label("Partager", systemImage: "square.and.arrow.up")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .disabled(loadedImage == nil)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .task { await loadImage() }
    }

    private var placeholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo").font(.largeTitle)
            Text("Image indisponible")
        }
        .foregroundStyle(.white.opacity(0.7))
    }

    private func loadImage() async {
        guard let imageURL else { didFail = true; return }
        do {
            let (data, _) = try await URLSession.shared.data(from: imageURL)
            if let image = UIImage(data: data) {
                loadedImage = image
            } else {
                didFail = true
            }
        } catch {
            didFail = true
        }
    }

    private func saveToPhotos() async {
        guard let image = loadedImage else { return }

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            show(message: "Accès à Photos refusé")
            return
        }

        do {
            // PhotoKit exécute ce bloc sur une file de fond. Il doit rester
            // `@Sendable` : sans ça, l'isolation MainActor par défaut du module
            // l'annote implicitement et la vérification d'exécuteur ajoutée par
            // Swift 6 fait planter l'app à l'enregistrement.
            try await PHPhotoLibrary.shared().performChanges { @Sendable in
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            show(message: "Enregistré dans Photos")
        } catch {
            show(message: "Échec de l'enregistrement")
        }
    }

    private func show(message: String) {
        withAnimation { saveMessage = message }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { saveMessage = nil }
        }
    }
}

// MARK: - Zoom

/// Affiche l'image dans un `UIScrollView` pour retrouver le zoom natif d'iOS :
/// pincement centré sur les doigts, déplacement libre et double tap sur le
/// point visé. `scaleEffect` ne sait zoomer que sur le centre de l'image.
private struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> ZoomableScrollView {
        let view = ZoomableScrollView()
        view.imageView.image = image
        return view
    }

    func updateUIView(_ view: ZoomableScrollView, context: Context) {
        guard view.imageView.image !== image else { return }
        view.imageView.image = image
        view.resetLayout()
    }
}

private final class ZoomableScrollView: UIScrollView, UIScrollViewDelegate {
    let imageView = UIImageView()

    /// Taille pour laquelle l'image a été calée, pour ne recalculer qu'au besoin.
    private var laidOutSize: CGSize = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)

        delegate = self
        minimumZoomScale = 1
        maximumZoomScale = 5
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        decelerationRate = .fast
        backgroundColor = .clear

        imageView.contentMode = .scaleAspectFit
        addSubview(imageView)

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) n'est pas utilisé")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.size != laidOutSize {
            laidOutSize = bounds.size
            resetLayout()
        }
        centerContent()
    }

    /// Cale l'image à sa taille « ajustée » et annule le zoom en cours.
    func resetLayout() {
        guard let size = imageView.image?.size, size.width > 0, size.height > 0,
              bounds.width > 0, bounds.height > 0 else { return }

        if zoomScale != minimumZoomScale { zoomScale = minimumZoomScale }
        let fit = min(bounds.width / size.width, bounds.height / size.height)
        imageView.frame = CGRect(origin: .zero,
                                 size: CGSize(width: size.width * fit, height: size.height * fit))
        contentSize = imageView.frame.size
        centerContent()
    }

    /// Garde l'image centrée tant qu'elle tient dans la vue.
    private func centerContent() {
        let horizontal = max((bounds.width - contentSize.width) / 2, 0)
        let vertical = max((bounds.height - contentSize.height) / 2, 0)
        contentInset = UIEdgeInsets(top: vertical, left: horizontal,
                                    bottom: vertical, right: horizontal)
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        guard zoomScale <= minimumZoomScale else {
            setZoomScale(minimumZoomScale, animated: true)
            return
        }

        // Zoome sur le point touché, pas sur le centre.
        let point = gesture.location(in: imageView)
        let target = min(maximumZoomScale, 3)
        let size = CGSize(width: bounds.width / target, height: bounds.height / target)
        zoom(to: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2,
                        width: size.width, height: size.height), animated: true)
    }

    // MARK: UIScrollViewDelegate

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

    func scrollViewDidZoom(_ scrollView: UIScrollView) { centerContent() }
}
