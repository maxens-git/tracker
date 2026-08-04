//
//  MediaDetailView.swift
//  Tracker
//

import SwiftUI

struct MediaDetailView: View {
    @State private var viewModel: MediaDetailViewModel
    @State private var showingPoster = false
    @State private var showingListPicker = false
    @Environment(\.openURL) private var openURL

    init(tmdbId: Int, type: MediaType) {
        _viewModel = State(initialValue: MediaDetailViewModel(tmdbId: tmdbId, type: type))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero
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
            .padding(.bottom)
        }
        // Le contenu démarre tout en haut de l'écran : le backdrop passe derrière la
        // barre de navigation (boutons retour / refresh) pour un en-tête immersif.
        .ignoresSafeArea(edges: .top)
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        // Barre transparente + contrôles clairs, lisibles par-dessus l'image.
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .errorToast($viewModel.errorMessage)
        .overlay {
            if viewModel.isLoading && viewModel.title.isEmpty {
                ProgressView()
            }
        }
        .toolbar {
            // L'affiche n'apparaît plus dans l'en-tête (la bannière est pleine
            // largeur) : elle reste accessible en plein écran depuis la barre.
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingPoster = true
                } label: {
                    Image(systemName: "photo")
                }
                .disabled(viewModel.posterPath == nil)
                .accessibilityLabel("Voir l'affiche")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.load(forceRefresh: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
                .accessibilityLabel("Rafraîchir")
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load(forceRefresh: true) }
        .fullScreenCover(isPresented: $showingPoster) {
            PosterFullScreenView(posterPath: viewModel.posterPath)
        }
    }

    // ── Sous-vues ─────────────────────────────────────────────────────────

    private func synopsisSection(_ overview: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Synopsis")
            ExpandableText(text: overview)
        }
        .padding(.horizontal)
    }

    private var movieFinancialSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                if let budget = viewModel.formattedBudget {
                    infoMetric(title: "Budget", value: budget, systemImage: "banknote")
                }
                if let revenue = viewModel.formattedRevenue {
                    infoMetric(title: "Recettes", value: revenue, systemImage: "chart.line.uptrend.xyaxis")
                }
            }
        }
        .padding(.horizontal)
    }

    private func infoMetric(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)

                Text(value)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .glassPanel(cornerRadius: AppRadius.small)
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

    // L'image occupe tout le haut de l'écran et le texte repose dessus : pas
    // d'affiche qui chevauche, la hiérarchie tient au dégradé et à la graisse
    // du titre (maquette Liquid Glass 2b).
    private let backdropHeight: CGFloat = 430

    /// En-tête immersif : backdrop pleine largeur fondu vers le fond de page,
    /// surmonté du surtitre, du titre et de la ligne de métadonnées.
    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            backdropLayer
            heroScrim
            heroInfo
        }
        .frame(maxWidth: .infinity)
        .frame(height: backdropHeight)
        .clipped()
    }

    /// Image large TMDB cadrée en hauteur fixe.
    ///
    /// C'est le `Color` qui porte la taille et l'image qui est posée en overlay :
    /// une image `scaledToFill` placée directement dans un `frame` impose sa
    /// largeur intrinsèque au reste de la page (à 430 pt de haut, un backdrop
    /// 16:9 fait ~760 pt de large et décentrait tout le contenu).
    private var backdropLayer: some View {
        Color.appSurface
            .frame(maxWidth: .infinity)
            .frame(height: backdropHeight)
            .overlay {
                // `original` : le hero est haut (430 pt) et pleine largeur, donc
                // fortement agrandi ; une taille w780/w1280 ressort visiblement
                // floue. L'image du hero est chargée une seule fois par fiche.
                RemoteImage(url: TMDBService.backdropURL(viewModel.backdropPath, size: "original")) {
                    Color.clear
                }
            }
            .clipped()
    }

    /// Voile sombre en haut (lisibilité des boutons de la barre) et fondu vers
    /// le fond de page en bas (transition douce vers le contenu).
    private var heroScrim: some View {
        // Deux couches : une vignette sombre (indépendante du thème) qui adosse le
        // titre et la note — en mode clair, `appBackground` est un crème pâle sur
        // lequel le texte blanc s'effacerait —, puis un fondu de page discret. La
        // vignette est revenue à `clear` avant le fondu : pas de mélange boueux.
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.4), location: 0),
                    .init(color: .clear, location: 0.30),
                    .init(color: .black.opacity(0.18), location: 0.58),
                    .init(color: .black.opacity(0.52), location: 0.82),
                    .init(color: .clear, location: 0.90)
                ],
                startPoint: .top, endPoint: .bottom
            )
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.90),
                    .init(color: Color.appBackground, location: 1)
                ],
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    /// Surtitre + titre + métadonnées, calés en bas de l'image.
    private var heroInfo: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: eyebrowText)

            Text(viewModel.title)
                .font(.display(32))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 9)
                .shadow(color: .black.opacity(0.45), radius: 16, x: 0, y: 3)

            metaRow
                .padding(.top, 12)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// « SÉRIE » / « FILM » — type du média seul. Le genre n'est pas repris ici :
    /// il est déjà affiché en chips sous les boutons d'action.
    private var eyebrowText: String {
        viewModel.type.label
    }

    private var metaRow: some View {
        let hasRating = (viewModel.rating ?? 0) > 0
        return HStack(spacing: 9) {
            if let rating = viewModel.rating, rating > 0 {
                ratingPill(rating)
            }
            if let releaseDate = viewModel.releaseDateDisplay {
                Text(releaseDate)
            }
            if let status = viewModel.showStatusLabel {
                // Séparateur seulement entre deux textes (date • statut) : la
                // pastille de note se suffit visuellement, pas de « • » après elle.
                if viewModel.releaseDateDisplay != nil && !hasRating {
                    Text("•").foregroundStyle(.white.opacity(0.35))
                }
                Text(status)
                    .foregroundStyle(viewModel.showIsEnded ? .white.opacity(0.78) : Color.appGreen)
            }
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.white.opacity(0.78))
    }

    private func ratingPill(_ rating: Double) -> some View {
        HStack(spacing: 3) {
            Text("★").foregroundStyle(Color.appAccent)
            Text(String(format: "%.1f", rating))
                .foregroundStyle(.white)
        }
        .font(.system(size: 12.5, weight: .bold))
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .glassEffect(.regular, in: .capsule)
    }

    /// Rangée d'actions : un CTA rouge plein (« vu ») puis des bascules carrées
    /// en verre, à la façon de la maquette.
    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                Task { await viewModel.toggleSeen() }
            } label: {
                Group {
                    if viewModel.seenPending {
                        ProgressView()
                            .tint(Color.appBackground)
                    } else {
                        Label(viewModel.seen ? "Vu" : "Marquer vu",
                              systemImage: viewModel.seen ? "checkmark.circle.fill" : "checkmark.circle")
                    }
                }
                .accentCTA()
            }
            .buttonStyle(.plain)
            .disabled(viewModel.seenPending)

            // Les bascules secondaires occupent une seconde ligne, à parts
            // égales : sur une seule ligne le CTA serait écrasé sur iPhone mini.
            HStack(spacing: 10) {
                glassToggle(title: "J'aime", systemImage: viewModel.liked ? "heart.fill" : "heart",
                            active: viewModel.liked, tint: .appAccent, busy: viewModel.likedPending) {
                    await viewModel.toggleLiked()
                }
                glassToggle(title: "À voir", systemImage: viewModel.inWatchlist ? "bookmark.fill" : "bookmark",
                            active: viewModel.inWatchlist, tint: .appGreen, busy: viewModel.watchlistPending) {
                    await viewModel.toggleWatchlist()
                }
                glassToggle(title: "Sortie", systemImage: viewModel.releaseTracked ? "bell.fill" : "bell",
                            active: viewModel.releaseTracked, tint: .blue, busy: viewModel.releasePending) {
                    await viewModel.toggleReleaseTracking()
                }
                if !viewModel.customLists.isEmpty {
                    glassToggle(title: "Listes",
                                systemImage: viewModel.isInAnyCustomList ? "text.badge.checkmark" : "text.badge.plus",
                                active: viewModel.isInAnyCustomList, tint: .appGreen) {
                        showingListPicker = true
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .sheet(isPresented: $showingListPicker) { listPickerSheet }
    }

    /// Bascule en verre : teintée quand l'état est actif, neutre sinon.
    private func glassToggle(title: String, systemImage: String, active: Bool,
                             tint: Color, busy: Bool = false,
                             action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            Group {
                if busy {
                    ProgressView()
                        .tint(active ? tint : .primary)
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(active ? tint : .primary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .glassEffect(active ? .regular.tint(tint.opacity(0.24)) : .regular,
                         in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(busy)
        .accessibilityLabel(title)
    }

    /// Feuille de sélection : ajoute / retire le média de chaque liste personnalisée.
    private var listPickerSheet: some View {
        NavigationStack {
            List(viewModel.customLists) { list in
                Button {
                    Task { await viewModel.toggleList(list.id) }
                } label: {
                    HStack(spacing: 12) {
                        Text(list.icon ?? "📋")
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


    // ── Saisons / épisodes ────────────────────────────────────────────────

    private var seasonsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Saisons")
                .padding(.horizontal)

            VStack(spacing: 10) {
                ForEach(viewModel.seasons) { season in
                    seasonBlock(season)
                }
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func seasonBlock(_ season: TMDBSeasonSummary) -> some View {
        let number = season.seasonNumber
        let episodeCount = season.episodeCount ?? 0
        let expanded = viewModel.expandedSeason == number
        let seen = viewModel.seenCount(inSeason: number)
        let fullySeen = viewModel.isSeasonFullySeen(number, episodeCount: episodeCount)

        VStack(spacing: 0) {
            HStack(spacing: 12) {
                PosterImage(path: season.posterPath)
                    .frame(width: 46, height: 69)

                VStack(alignment: .leading, spacing: 3) {
                    Text(season.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("\(episodeCount) épisodes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    // Progression dérivée des états (sans charger les épisodes).
                    if episodeCount > 0 {
                        ProgressView(value: min(Double(seen) / Double(episodeCount), 1))
                            .tint(.appGreen)
                        Text("\(seen)/\(episodeCount) vus")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Badge / bouton "tout vu" disponible dès l'ouverture.
                if episodeCount > 0 {
                    Button {
                        Task { await viewModel.toggleSeasonSeen(number, episodeCount: episodeCount) }
                    } label: {
                        Image(systemName: fullySeen ? "checkmark.circle.fill" : "checkmark.circle")
                            .font(.title3)
                            .foregroundStyle(fullySeen ? Color.appGreen : Color.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(expanded ? 90 : 0))
            }
            .glassPanel(cornerRadius: AppRadius.medium, padding: 12)
            .contentShape(Rectangle())
            .onTapGesture {
                Task { await viewModel.toggleSeason(number) }
            }

            if expanded {
                seasonEpisodesList(number)
            }
        }
    }

    @ViewBuilder
    private func seasonEpisodesList(_ season: Int) -> some View {
        if viewModel.loadingSeasons.contains(season) {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding()
        } else if let episodes = viewModel.seasonEpisodes[season], !episodes.isEmpty {
            // Un seul bloc de verre encastré pour toute la saison, lignes
            // séparées par un filet (maquette Liquid Glass).
            GlassRowGroup {
                ForEach(episodes) { episode in
                    episodeRow(season: season, episode: episode)
                    if episode.id != episodes.last?.id {
                        GlassRowDivider(leadingInset: 15)
                    }
                }
            }
            .padding(.top, 6)
        }
    }

    private func episodeRow(season: Int, episode: TMDBEpisode) -> some View {
        let seen = viewModel.isEpisodeSeen(season: season, episode: episode.episodeNumber)
        return HStack(spacing: 13) {
            // Photogramme de l'épisode avec son numéro incrusté ; à défaut, une
            // vignette neutre qui garde l'alignement de la liste.
            Color.appSurface
                .frame(width: 100, height: 58)
                .overlay {
                    RemoteImage(url: TMDBService.stillURL(episode.stillPath)) { Color.clear }
                }
                .overlay(alignment: .topLeading) {
                    Text("É\(episode.episodeNumber)")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.7), radius: 3, x: 0, y: 1)
                        .padding(6)
                }
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(episode.name)
                    .font(.system(size: 14.5, weight: .semibold))
                    .lineLimit(1)
                if let air = episode.airDate, !air.isEmpty {
                    Text(air + (episode.runtime.map { " · \($0) min" } ?? ""))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            Button {
                Task { await viewModel.toggleEpisodeSeen(season: season, episode: episode.episodeNumber) }
            } label: {
                Image(systemName: seen ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(seen ? Color.appGreen : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(seen ? "Marquer l'épisode non vu" : "Marquer l'épisode vu")
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 15)
    }

    // ── Bandes-annonces ───────────────────────────────────────────────────

    private var trailersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Bandes-annonces")
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(viewModel.trailers) { video in
                        Button {
                            if let url = TMDBService.youtubeWatch(video.key) { openURL(url) }
                        } label: {
                            trailerCard(video)
                        }
                        .buttonStyle(.plain)
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
                    Rectangle().fill(Color(.secondarySystemBackground))
                }
                .frame(width: 220, height: 124)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Image(systemName: "play.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(radius: 4)
            }
            Text(video.name)
                .font(.caption)
                .lineLimit(2)
                .frame(width: 220, alignment: .leading)
                .foregroundStyle(.primary)
        }
    }

    // ── Distribution ──────────────────────────────────────────────────────

    private var castSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Distribution")
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(viewModel.cast, id: \.stableId) { person in
                        NavigationLink(value: PersonRoute(personId: person.id)) {
                            personCard(name: person.name, role: person.character,
                                       profilePath: person.profilePath)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // ── Équipe ────────────────────────────────────────────────────────────

    private var crewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Équipe technique")
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(viewModel.crew, id: \.stableId) { person in
                        NavigationLink(value: PersonRoute(personId: person.id)) {
                            personCard(name: person.name, role: person.localizedJob,
                                       profilePath: person.profilePath)
                        }
                        .buttonStyle(.plain)
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
                    .fill(Color(.secondarySystemBackground))
                    .overlay(Image(systemName: "person.fill").foregroundStyle(.secondary))
            }
            .frame(width: 80, height: 80)
            .clipShape(Circle())

            Text(name)
                .font(.caption.weight(.medium))
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
                HStack(spacing: 14) {
                    ForEach(viewModel.similar) { item in
                        NavigationLink(value: MediaRoute(tmdbId: item.id, type: item.mediaType)) {
                            MediaCard(posterPath: item.posterPath,
                                      title: item.displayTitle,
                                      subtitle: item.year,
                                      seen: viewModel.isSimilarSeen(item))
                                .frame(width: 120)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

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
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)
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
