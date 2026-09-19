//
//  MediaDetailView.swift
//  Tracker
//
//  Fiche d'un film / d'une série : image large en tête, titre et métadonnées
//  en typographie système, actions en boutons standards, puis des sections de
//  contenu (synopsis, saisons, distribution…) présentées comme des cellules de
//  liste groupée.
//

import SwiftUI

struct MediaDetailView: View {
    @State private var viewModel: MediaDetailViewModel
    @State private var showingPoster = false
    @State private var showingListPicker = false
    @State private var showingImdb = false
    /// Le titre n'apparaît dans la barre qu'une fois l'en-tête défilé, pour
    /// laisser l'image respirer en haut de l'écran (comportement des fiches
    /// des apps média d'Apple).
    @State private var showsBarTitle = false
    /// Épisode dont le synopsis est déplié (un seul à la fois).
    @State private var expandedEpisodeId: Int?
    @Environment(\.openURL) private var openURL
    @Environment(\.zoomNamespace) private var zoomNamespace
    /// Namespace local de la transition zoom affiche → plein écran.
    @Namespace private var posterNamespace

    init(tmdbId: Int, type: MediaType) {
        _viewModel = State(initialValue: MediaDetailViewModel(tmdbId: tmdbId, type: type))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                actions
                if !viewModel.genres.isEmpty { genresRow }
                if let overview = viewModel.overview, !overview.isEmpty { synopsisSection(overview) }
                if viewModel.formattedBudget != nil || viewModel.formattedRevenue != nil { movieFinancialSection }
                if viewModel.type == .tv && !viewModel.seasons.isEmpty { seasonsSection }
                if !viewModel.trailers.isEmpty { trailersSection }
                if !viewModel.cast.isEmpty { castSection }
                if !viewModel.crew.isEmpty { crewSection }
                if !viewModel.similar.isEmpty { similarSection }
                if viewModel.isLoadingExtras { loadingExtrasIndicator }
            }
            .padding(.bottom, 24)
        }
        // L'image de tête monte jusqu'au bord de l'écran, sous la barre de
        // navigation translucide.
        .ignoresSafeArea(edges: .top)
        .background(Color.appBackground)
        // Titre de barre révélé au défilement : tant que l'affiche et le titre
        // de la page sont visibles, la barre reste vide et ne recouvre pas
        // l'image d'un bandeau redondant.
        .navigationTitle(showsBarTitle ? viewModel.title : "")
        .navigationBarTitleDisplayMode(.inline)
        // La barre ne prend son fond (verre) qu'au moment où elle porte le
        // titre : au repos, rien ne recouvre l'image ; une fois défilée, le
        // titre reste lisible par-dessus le contenu.
        .toolbarBackground(showsBarTitle ? .visible : .hidden, for: .navigationBar)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { _, offset in
            let shouldShow = offset > backdropHeight - 90
            if shouldShow != showsBarTitle {
                withAnimation(.easeInOut(duration: 0.2)) { showsBarTitle = shouldShow }
            }
        }
        .errorToast($viewModel.errorMessage)
        .overlay {
            if viewModel.isLoading && viewModel.title.isEmpty {
                ProgressView()
            }
        }
        .toolbar {
            // Une seule commande dans la barre : le reste passe par l'affiche
            // (tap) et le tirer-pour-rafraîchir.
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingPoster = true
                    } label: {
                        Label("Voir l'affiche", systemImage: "photo")
                    }
                    .disabled(viewModel.posterPath == nil)

                    Button {
                        Task { await viewModel.load(forceRefresh: true) }
                    } label: {
                        Label("Rafraîchir", systemImage: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                } label: {
                    Label("Options", systemImage: "ellipsis")
                }
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load(forceRefresh: true) }
        .fullScreenCover(isPresented: $showingPoster) {
            PosterFullScreenView(posterPath: viewModel.posterPath)
                // L'affiche plein écran s'ouvre en zoom depuis la vignette.
                .navigationTransition(.zoom(sourceID: "poster", in: posterNamespace))
        }
    }

    // ── En-tête ───────────────────────────────────────────────────────────

    private let backdropHeight: CGFloat = 280
    /// Débord de l'affiche sur l'image large.
    private let posterOverlap: CGFloat = 54

    /// Image large fondue vers le fond de page, puis l'affiche qui chevauche
    /// son bas, avec le titre et les métadonnées calés sur elle.
    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            // En-tête étirable : tiré vers le bas, l'image grandit et reste
            // collée au bord supérieur (comportement des fiches d'Apple Music).
            GeometryReader { geo in
                let stretch = max(0, geo.frame(in: .scrollView).minY)
                backdropLayer
                    .frame(width: geo.size.width, height: backdropHeight + stretch)
                    .overlay(alignment: .bottom) { backdropFade }
                    .clipped()
                    .offset(y: -stretch)
            }
            .frame(height: backdropHeight)

            HStack(alignment: .bottom, spacing: 16) {
                Button {
                    showingPoster = true
                } label: {
                    PosterImage(path: viewModel.posterPath,
                                cornerRadius: AppRadius.medium)
                        .frame(width: 106, height: 159)
                        // Ombre portée sur une forme opaque : l'affiche se
                        // détache du fond sans rasterisation coûteuse.
                        .background {
                            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                                .fill(Color.appSurface)
                                .shadow(color: .black.opacity(0.28), radius: 14, x: 0, y: 8)
                        }
                        .matchedTransitionSource(id: "poster", in: posterNamespace)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.posterPath == nil)
                .accessibilityLabel("Voir l'affiche")

                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.title)
                        .font(.title2.weight(.bold))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    metaRow
                }
                .padding(.bottom, 4)

                Spacer(minLength: 0)
            }
            .padding(.horizontal)
            .padding(.top, -posterOverlap)
        }
    }

    /// C'est le `Color` qui porte la taille et l'image qui est posée en overlay :
    /// une image `scaledToFill` placée directement dans un `frame` imposerait sa
    /// largeur intrinsèque au reste de la page.
    private var backdropLayer: some View {
        Color.appPlaceholder
            .frame(maxWidth: .infinity)
            .overlay {
                RemoteImage(url: TMDBService.backdropURL(viewModel.backdropPath, size: "w1280")) {
                    Color.clear
                }
            }
    }

    /// Fondu du bas de l'image vers le fond de page (dans les deux thèmes).
    private var backdropFade: some View {
        LinearGradient(stops: [
            .init(color: .clear, location: 0),
            .init(color: Color.appBackground.opacity(0.65), location: 0.55),
            .init(color: Color.appBackground, location: 1)
        ], startPoint: .top, endPoint: .bottom)
            .frame(height: 130)
    }

    private var metaRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if let rating = viewModel.rating, rating > 0 {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                    Text(String(format: "%.1f", rating))
                        .foregroundStyle(.primary)
                    Text("·")
                }
                Text(viewModel.type.label)
                if let releaseDate = viewModel.releaseDateDisplay {
                    Text("·")
                    Text(releaseDate)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.85)

            if let status = viewModel.showStatusLabel {
                Text(status)
                    .foregroundStyle(viewModel.showIsEnded ? .secondary : Color.appGreen)
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    // ── Actions ───────────────────────────────────────────────────────────

    /// Rangée d'actions discrète : une capsule « Marquer vu » compacte (le seul
    /// vrai appel à l'action, qui s'efface une fois le média vu), et les
    /// bascules secondaires réunies en icônes dans une même capsule de verre —
    /// l'état actif se lit dans le glyphe rempli et teinté, pas dans un fond.
    private var actions: some View {
        HStack(spacing: 12) {
            seenButton

            Spacer(minLength: 0)

            HStack(spacing: 0) {
                iconToggle(title: "J'aime", systemImage: "heart",
                           active: viewModel.liked, tint: .pink, busy: viewModel.likedPending) {
                    await viewModel.toggleLiked()
                }
                iconToggle(title: "À voir", systemImage: "bookmark",
                           active: viewModel.inWatchlist, tint: .accentColor, busy: viewModel.watchlistPending) {
                    await viewModel.toggleWatchlist()
                }
                iconToggle(title: "Suivre la sortie", systemImage: "bell",
                           active: viewModel.releaseTracked, tint: .orange, busy: viewModel.releasePending) {
                    await viewModel.toggleReleaseTracking()
                }
                if viewModel.imdbURL != nil {
                    Button {
                        showingImdb = true
                    } label: {
                        Image(systemName: "arrow.up.forward.app")
                            .font(.body.weight(.medium))
                            .foregroundStyle(Color.primary)
                            .frame(width: 46, height: 40)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Voir sur IMDb")
                }
                if !viewModel.customLists.isEmpty {
                    iconToggle(title: "Listes",
                               systemImage: viewModel.isInAnyCustomList ? "text.badge.checkmark" : "text.badge.plus",
                               active: viewModel.isInAnyCustomList, tint: .accentColor,
                               fillWhenActive: false) {
                        showingListPicker = true
                    }
                }
            }
            .glassEffect(.regular, in: .capsule)
        }
        .padding(.horizontal)
        .sheet(isPresented: $showingListPicker) { listPickerSheet }
        .sheet(isPresented: $showingImdb) {
            if let imdbURL = viewModel.imdbURL {
                SafariView(url: imdbURL).ignoresSafeArea()
            }
        }
    }

    /// « Marquer vu » : capsule proéminente tant que le média n'est pas vu,
    /// puis capsule de verre discrète avec coche verte une fois fait.
    @ViewBuilder
    private var seenButton: some View {
        let label = Group {
            if viewModel.seenPending {
                ProgressView()
            } else if viewModel.seen {
                Label("Vu", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Color.appGreen)
            } else {
                Label("Marquer vu", systemImage: "checkmark.circle")
            }
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 2)
        .frame(height: 24)

        if viewModel.seen {
            Button { Task { await viewModel.toggleSeen() } } label: { label }
                .buttonStyle(.glass)
                .disabled(viewModel.seenPending)
        } else {
            Button { Task { await viewModel.toggleSeen() } } label: { label }
                .buttonStyle(.glassProminent)
                .disabled(viewModel.seenPending)
        }
    }

    /// Icône-bascule logée dans la capsule de verre commune : glyphe rempli et
    /// teinté quand l'état est actif, neutre sinon.
    private func iconToggle(title: String, systemImage: String, active: Bool,
                            tint: Color, busy: Bool = false, fillWhenActive: Bool = true,
                            action: @escaping () async -> Void) -> some View {
        Button { Task { await action() } } label: {
            Group {
                if busy {
                    ProgressView()
                } else {
                    Image(systemName: active && fillWhenActive ? systemImage + ".fill" : systemImage)
                        .font(.body.weight(.medium))
                        .foregroundStyle(active ? tint : Color.primary)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .frame(width: 46, height: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(busy)
        .accessibilityLabel(title)
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    /// Feuille de sélection : ajoute / retire le média de chaque liste personnalisée.
    private var listPickerSheet: some View {
        NavigationStack {
            List(viewModel.customLists) { list in
                Button {
                    Task { await viewModel.toggleList(list.id) }
                } label: {
                    HStack(spacing: 12) {
                        Text(list.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        if viewModel.isInList(list.id) {
                            Image(systemName: "checkmark")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.tint)
                        }
                    }
                }
                .disabled(viewModel.listPendingId == list.id)
            }
            .navigationTitle("Ajouter à une liste")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { showingListPicker = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // ── Sections de contenu ───────────────────────────────────────────────

    private var genresRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.genres) { genre in
                    TagChip(label: genre.name)
                }
            }
            .padding(.horizontal)
        }
    }

    private func synopsisSection(_ overview: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Synopsis")
            ExpandableText(text: overview)
        }
        .padding(.horizontal)
    }

    private var movieFinancialSection: some View {
        CardGroup {
            if let budget = viewModel.formattedBudget {
                financialRow(title: "Budget", value: budget)
                if viewModel.formattedRevenue != nil { RowDivider() }
            }
            if let revenue = viewModel.formattedRevenue {
                financialRow(title: "Recettes", value: revenue)
            }
        }
        .padding(.horizontal)
    }

    private func financialRow(title: String, value: String) -> some View {
        LabeledContent(title) {
            Text(value).monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    private var loadingExtrasIndicator: some View {
        HStack(spacing: 8) {
            ProgressView()
            Text("Chargement…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // ── Saisons / épisodes ────────────────────────────────────────────────

    /// Une seule saison à l'écran, choisie dans un menu en verre — le patron
    /// de l'app TV. Pas d'accordéon, pas de cartes empilées : un titre, un
    /// sélecteur, une jauge, puis la liste d'épisodes.
    @ViewBuilder
    private var seasonsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            seasonsHeader

            if let number = viewModel.expandedSeason,
               let season = viewModel.seasons.first(where: { $0.seasonNumber == number }) {
                seasonProgress(season)
                seasonEpisodesList(number)
            }
        }
        .padding(.horizontal)
        .animation(.snappy(duration: 0.3), value: viewModel.expandedSeason)
        .animation(.snappy(duration: 0.25), value: expandedEpisodeId)
    }

    /// « Saisons » et, à droite, la capsule de verre qui ouvre le choix des saisons.
    private var seasonsHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Saisons")
                .font(.title3.weight(.semibold))

            Spacer(minLength: 12)

            Menu {
                Picker("Saison", selection: seasonSelection) {
                    ForEach(viewModel.seasons) { season in
                        Text(season.name).tag(Optional(season.seasonNumber))
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(currentSeasonName)
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.bold))
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .glassEffect(.regular.interactive(), in: .capsule)
            }
            .accessibilityLabel("Choisir une saison")
        }
    }

    /// Saison affichée, reliée au menu (la sélection charge les épisodes).
    private var seasonSelection: Binding<Int?> {
        Binding(get: { viewModel.expandedSeason },
                set: { value in
                    guard let value else { return }
                    Task { await viewModel.selectSeason(value) }
                })
    }

    private var currentSeasonName: String {
        guard let number = viewModel.expandedSeason,
              let season = viewModel.seasons.first(where: { $0.seasonNumber == number })
        else { return "Saison" }
        return season.name
    }

    /// Jauge de la saison affichée, avec le bouton « tout marquer vu » en verre.
    @ViewBuilder
    private func seasonProgress(_ season: TMDBSeasonSummary) -> some View {
        let number = season.seasonNumber
        let count = season.episodeCount ?? 0
        let seen = viewModel.seenCount(inSeason: number)
        let fullySeen = viewModel.isSeasonFullySeen(number, episodeCount: count)

        if count > 0 {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 7) {
                    ProgressStripe(progress: Double(seen) / Double(count), height: 6,
                                   tint: .appGreen, track: Color(.tertiarySystemFill))

                    Text(fullySeen ? "Saison vue" : "\(seen) sur \(count) épisodes vus")
                        .font(.caption)
                        .foregroundStyle(fullySeen ? Color.appGreen : .secondary)
                }

                Button {
                    Task { await viewModel.toggleSeasonSeen(number, episodeCount: count) }
                } label: {
                    Image(systemName: fullySeen ? "checkmark.circle.fill" : "checkmark.circle")
                        .font(.body.weight(.medium))
                        .foregroundStyle(fullySeen ? Color.appGreen : Color.primary)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.glass)
                .accessibilityLabel(fullySeen ? "Marquer la saison non vue" : "Marquer toute la saison vue")
            }
        }
    }

    @ViewBuilder
    private func seasonEpisodesList(_ season: Int) -> some View {
        if viewModel.loadingSeasons.contains(season) {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        } else if let episodes = viewModel.seasonEpisodes[season], !episodes.isEmpty {
            CardGroup {
                ForEach(episodes) { episode in
                    episodeRow(season: season, episode: episode)
                    if episode.id != episodes.last?.id {
                        // Filet calé sous le texte, comme les séparateurs de liste.
                        RowDivider(leadingInset: 140)
                    }
                }
            }
        } else {
            Text("Aucun épisode annoncé pour cette saison.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .cardBackground()
        }
    }

    /// Ligne d'épisode : photogramme, « ÉPISODE 3 » en surtitre, titre, date et
    /// durée, puis le synopsis tronqué que le toucher déplie.
    private func episodeRow(season: Int, episode: TMDBEpisode) -> some View {
        let seen = viewModel.isEpisodeSeen(season: season, episode: episode.episodeNumber)
        let upcoming = isUpcoming(episode)
        let synopsisOpen = expandedEpisodeId == episode.id
        let overview = episode.overview ?? ""

        return VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 14) {
                episodeStill(episode, seen: seen, upcoming: upcoming)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Épisode \(episode.episodeNumber)")
                        .font(.caption2.weight(.semibold))
                        .textCase(.uppercase)
                        .kerning(0.5)
                        .foregroundStyle(.secondary)

                    Text(episode.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(seen ? .secondary : .primary)
                        .lineLimit(2)

                    let meta = episodeMeta(episode)
                    if !meta.isEmpty {
                        Text(meta)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                Button {
                    Task { await viewModel.toggleEpisodeSeen(season: season, episode: episode.episodeNumber) }
                } label: {
                    Image(systemName: seen ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(seen ? Color.appGreen : Color.secondary)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(seen ? "Marquer l'épisode non vu" : "Marquer l'épisode vu")
            }

            if !overview.isEmpty {
                Text(overview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(synopsisOpen ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !overview.isEmpty else { return }
            expandedEpisodeId = synopsisOpen ? nil : episode.id
        }
    }

    /// Photogramme 16:9 de l'épisode, atténué une fois l'épisode vu. Les
    /// épisodes non encore diffusés portent leur pastille ici plutôt que dans
    /// la colonne de texte, trop étroite pour l'accueillir.
    private func episodeStill(_ episode: TMDBEpisode, seen: Bool, upcoming: Bool) -> some View {
        Color.appPlaceholder
            .frame(width: 112, height: 63)
            .overlay {
                RemoteImage(url: TMDBService.stillURL(episode.stillPath)) {
                    Image(systemName: "tv")
                        .foregroundStyle(.tertiary)
                }
            }
            .overlay(alignment: .bottomLeading) {
                if upcoming {
                    Text("À venir")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .glassEffect(.regular, in: .capsule)
                        .environment(\.colorScheme, .dark)
                        .padding(5)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .opacity(seen ? 0.5 : 1)
    }

    /// « 24 juin 2026 · 42 min ».
    private func episodeMeta(_ episode: TMDBEpisode) -> String {
        var parts: [String] = []
        if let air = episode.airDate, !air.isEmpty {
            parts.append(DateOnlyFormatter.display(air))
        }
        if let runtime = episode.runtime, runtime > 0 {
            parts.append("\(runtime) min")
        }
        return parts.joined(separator: " · ")
    }

    /// Épisode dont la date de diffusion est encore à venir.
    private func isUpcoming(_ episode: TMDBEpisode) -> Bool {
        guard let air = episode.airDate, let date = DateOnlyFormatter.date(from: air) else { return false }
        return date > Date()
    }

    // ── Bandes-annonces ───────────────────────────────────────────────────

    private var trailersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Bandes-annonces")
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(viewModel.trailers) { video in
                        Button {
                            if let url = TMDBService.youtubeWatch(video.key) { openURL(url) }
                        } label: {
                            trailerCard(video)
                        }
                        .buttonStyle(.pressableCard)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    /// Vignette YouTube + titre, avec un bouton lecture superposé.
    private func trailerCard(_ video: TMDBVideo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                AsyncImage(url: TMDBService.youtubeThumbnail(video.key)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color.appPlaceholder)
                }
                .frame(width: 220, height: 124)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))

                GlassPlayBadge()
            }
            Text(video.name)
                .font(.caption)
                .lineLimit(2)
                .frame(width: 220, alignment: .leading)
                .foregroundStyle(.primary)
        }
    }

    // ── Distribution / équipe ─────────────────────────────────────────────

    private var castSection: some View {
        peopleSection("Distribution", people: viewModel.cast.map {
            (id: $0.stableId, personId: $0.id, name: $0.name, role: $0.character, path: $0.profilePath)
        })
    }

    private var crewSection: some View {
        peopleSection("Équipe technique", people: viewModel.crew.map {
            (id: $0.stableId, personId: $0.id, name: $0.name, role: $0.localizedJob, path: $0.profilePath)
        })
    }

    private func peopleSection(
        _ title: String,
        people: [(id: String, personId: Int, name: String, role: String?, path: String?)]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(people, id: \.id) { person in
                        NavigationLink(value: PersonRoute(personId: person.personId)) {
                            personCard(name: person.name, role: person.role, profilePath: person.path)
                        }
                        .buttonStyle(.pressableCard)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func personCard(name: String, role: String?, profilePath: String?) -> some View {
        VStack(spacing: 6) {
            AsyncImage(url: TMDBService.profileURL(profilePath)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle()
                    .fill(Color.appPlaceholder)
                    .overlay(Image(systemName: "person.fill").foregroundStyle(.secondary))
            }
            .frame(width: 80, height: 80)
            .clipShape(Circle())

            Text(name)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            if let role, !role.isEmpty {
                Text(role)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(width: 90)
    }

    private var similarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Similaires")
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(viewModel.similar) { item in
                        let route = MediaRoute(tmdbId: item.id, type: item.mediaType, source: "similar-\(viewModel.tmdbId)")
                        NavigationLink(value: route) {
                            MediaCard(posterPath: item.posterPath,
                                      title: item.displayTitle,
                                      subtitle: item.year,
                                      seen: viewModel.isSimilarSeen(item))
                                .frame(width: 120)
                                .zoomSource(route, in: zoomNamespace)
                        }
                        .buttonStyle(.pressableCard)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// ── Texte repliable ───────────────────────────────────────────────────────

/// Texte tronqué à `collapsedLimit` lignes avec un bouton « Voir plus / Voir moins ».
/// Le bouton n'apparaît que si le texte dépasse réellement la limite (mesuré hors écran).
private struct ExpandableText: View {
    let text: String
    var collapsedLimit: Int = 4

    @State private var expanded = false
    @State private var fullHeight: CGFloat = 0
    @State private var limitedHeight: CGFloat = 0

    private var isTruncated: Bool { fullHeight > limitedHeight + 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text)
                .foregroundStyle(.secondary)
                .lineLimit(expanded ? nil : collapsedLimit)
                .fixedSize(horizontal: false, vertical: true)
                .animation(.easeInOut(duration: 0.2), value: expanded)

            if isTruncated {
                Button(expanded ? "Voir moins" : "Voir plus") {
                    withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                }
                .font(.subheadline)
            }
        }
        .background(measurement)
    }

    /// Deux rendus masqués (texte complet vs tronqué) à la même largeur, pour comparer
    /// leur hauteur et savoir si la troncature s'applique.
    private var measurement: some View {
        ZStack(alignment: .top) {
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
                .background(heightReader { fullHeight = $0 })
            Text(text)
                .lineLimit(collapsedLimit)
                .fixedSize(horizontal: false, vertical: true)
                .background(heightReader { limitedHeight = $0 })
        }
        .hidden()
        .allowsHitTesting(false)
    }

    private func heightReader(_ update: @escaping (CGFloat) -> Void) -> some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { update(proxy.size.height) }
                .onChange(of: proxy.size.height) { _, newValue in update(newValue) }
        }
    }
}
