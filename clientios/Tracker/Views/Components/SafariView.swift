//
//  SafariView.swift
//  Tracker
//
//  Wrapper SwiftUI autour de SFSafariViewController : ouvre un lien externe
//  (ex. IMDb) dans une fenêtre Safari intégrée, sans quitter l'app.
//

import SwiftUI
import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
