//
//  DebridSheet.swift
//  Tracker
//
//  Popup des liens débridés d'un torrent : métadonnées, résolution des liens
//  (à la demande ou en masse), copie et téléchargement.
//

import SwiftUI

struct DebridSheet: View {
    @Bindable var viewModel: TorrentsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let torrent = viewModel.debridTorrent {
                        header(torrent)
                    }
                    if viewModel.debridFiles.count > 1 {
                        bulkActions
                    }
                    filesList
                }
                .padding()
            }
            .background(Color.appBackground)
            .navigationTitle("Liens débridés")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    // ── En-tête ──────────────────────────────────────────────────────────────

    private func header(_ torrent: TorrentResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(torrent.title)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)

            FlowRow(spacing: 8) {
                chip(icon: "server.rack", text: torrent.indexer)
                chip(icon: "arrow.up", text: "\(torrent.seeders) seeders", tint: .green)
                chip(icon: "internaldrive", text: ByteFormat.string(viewModel.totalDebridSize > 0 ? viewModel.totalDebridSize : torrent.size))
                chip(icon: "doc.on.doc", text: "\(viewModel.debridFiles.count) fichier\(viewModel.debridFiles.count > 1 ? "s" : "")")
            }
        }
    }

    private func chip(icon: String, text: String, tint: Color = .secondary) -> some View {
        Label(text, systemImage: icon)
            .font(.footnote)
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(.tertiarySystemFill), in: .capsule)
    }

    // ── Actions groupées ─────────────────────────────────────────────────────

    private var bulkActions: some View {
        VStack(spacing: 10) {
            if viewModel.hasUnresolved {
                Button {
                    Task { await viewModel.resolveAll() }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.resolvingAll {
                            ProgressView()
                            Text("Obtention… (\(viewModel.resolvedCount)/\(viewModel.debridFiles.count))")
                        } else {
                            Image(systemName: "bolt.fill")
                            Text("Obtenir tous les liens")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.unlockingLink != nil)
            }

            if viewModel.resolvedCount > 0 {
                HStack(spacing: 10) {
                    Button {
                        viewModel.toggleSelectAll()
                    } label: {
                        Label(viewModel.allResolvedSelected ? "Tout décocher" : "Tout cocher",
                              systemImage: viewModel.allResolvedSelected ? "checklist.unchecked" : "checklist.checked")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button {
                        viewModel.copySelected()
                    } label: {
                        Label(viewModel.selectedCount > 0 ? "Copier (\(viewModel.selectedCount))" : "Copier",
                              systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(viewModel.selectedCount == 0 || viewModel.resolvingAll)
                }
            }
        }
    }

    // ── Liste des fichiers ───────────────────────────────────────────────────

    private var filesList: some View {
        VStack(spacing: 10) {
            ForEach(Array(viewModel.debridFiles.enumerated()), id: \.offset) { _, file in
                DebridFileRow(file: file, viewModel: viewModel)
            }
        }
    }
}

// MARK: - Ligne d'un fichier

private struct DebridFileRow: View {
    let file: DebridFile
    @Bindable var viewModel: TorrentsViewModel

    private var directLink: String? { viewModel.resolvedLink(file) }
    private var isUnlocking: Bool { viewModel.unlockingLink == file.link }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                // Case à cocher pour la copie groupée, une fois le lien résolu.
                if directLink != nil {
                    Button {
                        viewModel.toggleSelection(file)
                    } label: {
                        Image(systemName: viewModel.isSelected(file) ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(viewModel.isSelected(file) ? Color.accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(viewModel.isSelected(file) ? "Décocher" : "Cocher")
                }

                let ext = file.filename.fileExtensionUppercased
                if !ext.isEmpty {
                    Text(ext)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(file.filename.isEmpty ? "Fichier" : file.filename)
                        .font(.subheadline)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(ByteFormat.string(file.size))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            actions
        }
        .cardBackground(padding: 12)
    }

    @ViewBuilder
    private var actions: some View {
        if let directLink, let url = URL(string: directLink) {
            HStack(spacing: 10) {
                Button {
                    viewModel.copy(directLink)
                } label: {
                    Label("Copier", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Link(destination: url) {
                    Label("Télécharger", systemImage: "arrow.down.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        } else {
            Button {
                Task { await viewModel.resolve(file) }
            } label: {
                HStack(spacing: 8) {
                    if isUnlocking {
                        ProgressView()
                    } else {
                        Image(systemName: "bolt")
                    }
                    Text("Obtenir le lien")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.unlockingLink != nil)
        }
    }
}

// MARK: - Disposition en lignes (wrap) pour les puces de métadonnées

/// Simple flow layout : place les enfants sur plusieurs lignes selon la largeur.
struct FlowRow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                totalWidth = max(totalWidth, rowWidth - spacing)
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        totalWidth = max(totalWidth, rowWidth - spacing)
        return CGSize(width: min(totalWidth, maxWidth), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
