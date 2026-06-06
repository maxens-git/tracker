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

    // Zoom / déplacement.
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

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
                    Image(uiImage: loadedImage)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .gesture(magnification)
                        .onTapGesture(count: 2) { resetZoom() }
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
                            saveToPhotos()
                        } label: {
                            Label("Enregistrer dans Photos", systemImage: "square.and.arrow.down")
                        }
                        .disabled(loadedImage == nil)

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

    private var magnification: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(lastScale * value, 1), 5)
            }
            .onEnded { _ in
                lastScale = scale
            }
    }

    private func resetZoom() {
        withAnimation(.spring(response: 0.3)) {
            scale = 1
            lastScale = 1
        }
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

    private func saveToPhotos() {
        guard let loadedImage else { return }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                guard status == .authorized || status == .limited else {
                    show(message: "Accès à Photos refusé")
                    return
                }
                PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: loadedImage)
                } completionHandler: { success, _ in
                    DispatchQueue.main.async {
                        show(message: success ? "Enregistré dans Photos" : "Échec de l'enregistrement")
                    }
                }
            }
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
