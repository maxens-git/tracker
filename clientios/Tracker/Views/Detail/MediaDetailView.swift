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
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.appStroke, lineWidth: 1)
        )
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

    // Dimensions de l'en-tête (fixes pour un chevauchement net et sans débordement).
    // Hauteur calée sur le ratio 16:9 d'un backdrop à la largeur d'un iPhone (~220pt) :
    // au-delà, `scaledToFill` rogne fort l'image et donne un effet « zoom ». Le backdrop
    // démarre tout en haut de l'écran (cf. ignoresSafeArea), donc sa partie haute passe
    // simplement derrière la barre de navigation, sans grossir l'image.
    private let backdropHeight: CGFloat = 230
    private let heroPosterWidth: CGFloat = 110
    private let heroPosterHeight: CGFloat = 165
    private let posterOverlap: CGFloat = 55   // remontée de l'affiche sur le backdrop

    /// En-tête immersif type Infuse : grande image (backdrop) du média fondue par un
    /// dégradé vers le fond de page, avec l'affiche qui chevauche le bas et le titre à côté.
    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            backdropLayer
            heroInfo
                .padding(.horizontal)
                .padding(.top, -posterOverlap)
        }
    }

    /// Image large TMDB cadrée en hauteur fixe, recouverte d'un dégradé qui se
    /// fond progressivement dans `appBackground` (transition douce vers le contenu).
    private var backdropLayer: some View {
        AsyncImage(url: TMDBService.backdropURL(viewModel.backdropPath, size: "w780")) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                Color(.secondarySystemBackground)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: backdropHeight)
        .clipped()
        // Voile sombre en haut : lisibilité des boutons de la barre par-dessus l'image.
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [.black.opacity(0.45), .clear],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 140)
        }
        // Fondu vers le fond de page en bas, pour une transition douce vers le contenu.
        .overlay {
            LinearGradient(
                colors: [.clear, .clear, Color.appBackground.opacity(0.7), Color.appBackground],
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    /// Affiche (taille fixe + ombre portée) + titre / type / note, alignés en bas.
    private var heroInfo: some View {
        HStack(alignment: .bottom, spacing: 14) {
            PosterImage(path: viewModel.posterPath)
                .frame(width: heroPosterWidth, height: heroPosterHeight)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                .contentShape(Rectangle())
                .onTapGesture {
                    if viewModel.posterPath != nil { showingPoster = true }
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(viewModel.title)
                    .font(.display(24))
                    .fixedSize(horizontal: false, vertical: true)
                Label(viewModel.type.label, systemImage: viewModel.type.symbol)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                // Film : date de sortie. Série : statut terminé / en cours.
                if let releaseDate = viewModel.releaseDateDisplay {
                    Label(releaseDate, systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let status = viewModel.showStatusLabel {
                    Label(status, systemImage: viewModel.showIsEnded ? "checkmark.seal.fill" : "dot.radiowaves.up.forward")
                        .font(.subheadline)
                        .foregroundStyle(viewModel.showIsEnded ? .secondary : Color.appGreen)
                }
                if let rating = viewModel.rating, rating > 0 {
                    Label(String(format: "%.1f", rating), systemImage: "star.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appGold)
                }
            }
            .padding(.bottom, 6)

            Spacer(minLength: 0)
        }
    }

    private var actions: some View {
        HStack(spacing: 12) {
            actionButton(title: "Vu", systemImage: viewModel.seen ? "checkmark.circle.fill" : "checkmark.circle",
                         active: viewModel.seen) {
                await viewModel.toggleSeen()
            }
            actionButton(title: "J'aime", systemImage: viewModel.liked ? "heart.fill" : "heart",
                         active: viewModel.liked, tint: .red) {
                await viewModel.toggleLiked()
            }
            actionButton(title: "À voir", systemImage: viewModel.inWatchlist ? "bookmark.fill" : "bookmark",
                         active: viewModel.inWatchlist) {
                await viewModel.toggleWatchlist()
            }
            actionButton(title: "Sortie", systemImage: viewModel.releaseTracked ? "bell.fill" : "bell",
                         active: viewModel.releaseTracked, tint: .blue) {
                await viewModel.toggleReleaseTracking()
            }
            if !viewModel.customLists.isEmpty {
                actionButton(title: "Listes", systemImage: viewModel.isInAnyCustomList ? "text.badge.checkmark" : "text.badge.plus",
                             active: viewModel.isInAnyCustomList) {
                    showingListPicker = true
                }
            }
        }
        .padding(.horizontal)
        .sheet(isPresented: $showingListPicker) { listPickerSheet }
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

    private func actionButton(title: String, systemImage: String, active: Bool = false,
                              tint: Color = .accentColor, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: systemImage).font(.title3)
                Text(title).font(.caption.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(active ? AnyShapeStyle(tint.opacity(0.15)) : AnyShapeStyle(.ultraThinMaterial))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(active ? tint.opacity(0.4) : Color.primary.opacity(0.06), lineWidth: 1)
            }
            .foregroundStyle(active ? tint : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
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
            .cinemaCard(cornerRadius: 12, padding: 10)
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
            VStack(spacing: 0) {
                ForEach(episodes) { episode in
                    episodeRow(season: season, episode: episode)
                    if episode.id != episodes.last?.id {
                        Divider().padding(.leading, 46)
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    private func episodeRow(season: Int, episode: TMDBEpisode) -> some View {
        let seen = viewModel.isEpisodeSeen(season: season, episode: episode.episodeNumber)
        return HStack(spacing: 12) {
            Text("\(episode.episodeNumber)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(episode.name)
                    .font(.subheadline)
                    .lineLimit(1)
                if let air = episode.airDate, !air.isEmpty {
                    Text(air + (episode.runtime.map { " · \($0) min" } ?? ""))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                Task { await viewModel.toggleEpisodeSeen(season: season, episode: episode.episodeNumber) }
            } label: {
                Image(systemName: seen ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(seen ? Color.appGreen : Color.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
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
