//
//  TorrentsView.swift
//  Tracker
//
//  Recherche torrents + débridage (transposé de la page web `torrents`).
//

import SwiftUI

struct TorrentsView: View {
    @State private var viewModel = TorrentsViewModel()
    @State private var showingIndexerPicker = false

    var body: some View {
        VStack(spacing: 14) {
            tabPicker
            if viewModel.tab == .results {
                filters
            }
            contentArea
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.appBackground)
        .navigationTitle("Torrents")
        .searchable(text: $viewModel.query, prompt: "Rechercher un torrent…")
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .onSubmit(of: .search) { Task { await viewModel.search() } }
        .errorToast($viewModel.errorMessage)
        .task {
            await viewModel.loadFilters()
            await viewModel.loadBookmarks()
        }
        .sheet(isPresented: $showingIndexerPicker, onDismiss: { Task { await viewModel.onFilterChange() } }) {
            indexerPicker
        }
        .sheet(isPresented: $viewModel.showingDebrid) {
            DebridSheet(viewModel: viewModel)
        }
    }

    // ── Filtres (indexeurs + catégorie) ──────────────────────────────────────

    private var filters: some View {
        HStack(spacing: 10) {
            filterChip(icon: "server.rack", label: viewModel.indexersLabel,
                       active: !viewModel.selectedIndexers.isEmpty) {
                showingIndexerPicker = true
            }

            Menu {
                Picker("Catégorie", selection: $viewModel.selectedCategory) {
                    Text("Toutes les catégories").tag(Int?.none)
                    ForEach(viewModel.categories) { cat in
                        Text(cat.name).tag(Int?.some(cat.id))
                    }
                }
            } label: {
                filterChipLabel(icon: "square.grid.2x2", label: viewModel.selectedCategoryName,
                                active: viewModel.selectedCategory != nil)
            }
            .buttonStyle(.bordered)
            .onChange(of: viewModel.selectedCategory) { Task { await viewModel.onFilterChange() } }
        }
        .padding(.horizontal)
    }

    private func filterChip(icon: String, label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            filterChipLabel(icon: icon, label: label, active: active)
        }
        .buttonStyle(.bordered)
    }

    private func filterChipLabel(icon: String, label: String, active: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.caption)
            Text(label).lineLimit(1)
            Image(systemName: "chevron.down").font(.caption2)
        }
        .font(.subheadline)
        .foregroundStyle(active ? Color.accentColor : .primary)
        .frame(maxWidth: .infinity)
    }

    // ── Onglet Résultats / Marque-pages ──────────────────────────────────────

    private var tabPicker: some View {
        Picker("Affichage", selection: $viewModel.tab) {
            Text("Marque-pages").tag(TorrentsTab.bookmarks)
            Text("Résultats").tag(TorrentsTab.results)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }

    @ViewBuilder
    private var contentArea: some View {
        switch viewModel.tab {
        case .results:   resultsArea
        case .bookmarks: bookmarksArea
        }
    }

    @ViewBuilder
    private var bookmarksArea: some View {
        if viewModel.bookmarks.isEmpty {
            Spacer()
            ContentUnavailableView("Aucun marque-page", systemImage: "bookmark",
                                   description: Text("Mettez un torrent de côté depuis les résultats."))
            Spacer()
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.bookmarks) { bookmark in
                        TorrentRow(torrent: bookmark.asResult, viewModel: viewModel)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .refreshable { await viewModel.loadBookmarks() }
        }
    }

    // ── Résultats ────────────────────────────────────────────────────────────

    @ViewBuilder
    private var resultsArea: some View {
        if viewModel.isLoading {
            Spacer()
            ProgressView()
            Spacer()
        } else if viewModel.hasSearched && viewModel.results.isEmpty {
            Spacer()
            ContentUnavailableView("Aucun torrent", systemImage: "magnifyingglass",
                                   description: Text("Aucun résultat pour cette recherche."))
            Spacer()
        } else if viewModel.results.isEmpty {
            Spacer()
            ContentUnavailableView("Recherche torrents", systemImage: "arrow.down.circle",
                                   description: Text("Cherchez un torrent, puis débridez-le via AllDebrid."))
            Spacer()
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(Array(viewModel.results.enumerated()), id: \.offset) { _, torrent in
                        TorrentRow(torrent: torrent, viewModel: viewModel)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
    }

    // ── Feuille de sélection des indexeurs ───────────────────────────────────

    private var indexerPicker: some View {
        NavigationStack {
            List {
                Section {
                    Button("Tous les indexeurs") { viewModel.selectedIndexers = [] }
                        .foregroundStyle(viewModel.selectedIndexers.isEmpty ? Color.accentColor : .primary)
                }
                Section {
                    ForEach(viewModel.indexers) { indexer in
                        Button {
                            toggleIndexer(indexer.id)
                        } label: {
                            HStack {
                                Text(indexer.name).foregroundStyle(.primary)
                                Spacer()
                                if viewModel.selectedIndexers.contains(indexer.id) {
                                    Image(systemName: "checkmark").foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Indexeurs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { showingIndexerPicker = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func toggleIndexer(_ id: Int) {
        if viewModel.selectedIndexers.contains(id) {
            viewModel.selectedIndexers.remove(id)
        } else {
            viewModel.selectedIndexers.insert(id)
        }
    }
}

// MARK: - Ligne de résultat

private struct TorrentRow: View {
    let torrent: TorrentResult
    let viewModel: TorrentsViewModel

    private var isDebriding: Bool { viewModel.debridingMagnet == torrent.magnetUrl }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(torrent.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 14) {
                meta(icon: "server.rack", text: torrent.indexer)
                meta(icon: "internaldrive", text: ByteFormat.string(torrent.size))
                Label("\(torrent.seeders)", systemImage: "arrow.up")
                    .foregroundStyle(Color.green)
                Label("\(torrent.leechers)", systemImage: "arrow.down")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            .lineLimit(1)

            HStack(spacing: 10) {
                debridButton
                bookmarkButton
            }
        }
        .cardBackground(padding: 14)
    }

    private func meta(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    private var debridButton: some View {
        Button {
            Task { await viewModel.debrid(torrent) }
        } label: {
            HStack(spacing: 8) {
                if isDebriding {
                    ProgressView()
                } else {
                    Image(systemName: "bolt.fill")
                }
                Text("Débrider")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.debridingMagnet != nil)
    }

    /// Bouton « mettre de côté » : ajoute / retire le torrent des marque-pages.
    private var bookmarkButton: some View {
        let bookmarked = viewModel.isBookmarked(torrent.magnetUrl)
        let busy = viewModel.isBookmarking(torrent.magnetUrl)

        return Button {
            Task { await viewModel.toggleBookmark(torrent) }
        } label: {
            Group {
                if busy {
                    ProgressView()
                } else {
                    Image(systemName: bookmarked ? "bookmark.fill" : "bookmark")
                }
            }
            .frame(width: 28)
        }
        .buttonStyle(.bordered)
        .disabled(busy)
        .accessibilityLabel(bookmarked ? "Retirer des marque-pages" : "Mettre de côté")
    }
}
