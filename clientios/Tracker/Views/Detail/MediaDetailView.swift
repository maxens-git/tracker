//
//  MediaDetailView.swift
//  Tracker
//

import SwiftUI

struct MediaDetailView: View {
    @State private var viewModel: MediaDetailViewModel
    @Environment(\.openURL) private var openURL

    init(tmdbId: Int, type: MediaType) {
        _viewModel = State(initialValue: MediaDetailViewModel(tmdbId: tmdbId, type: type))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                actions
                if !viewModel.genres.isEmpty { genresRow }
                if let overview = viewModel.overview, !overview.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Synopsis").font(.headline)
                        Text(overview).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }
                if viewModel.type == .tv && !viewModel.seasons.isEmpty { seasonsSection }
                if !viewModel.trailers.isEmpty { trailersSection }
                if !viewModel.cast.isEmpty { castSection }
                if !viewModel.crew.isEmpty { crewSection }
                if !viewModel.similar.isEmpty { similarSection }
            }
            .padding(.vertical)
        }
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if viewModel.isLoading && viewModel.title.isEmpty {
                ProgressView()
            }
        }
        .task { await viewModel.load() }
    }

    // ── Sous-vues ─────────────────────────────────────────────────────────

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            PosterImage(path: viewModel.posterPath)
                .aspectRatio(2.0 / 3.0, contentMode: .fit)
                .frame(width: 130)

            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.title)
                    .font(.title2.bold())
                Label(viewModel.type.label, systemImage: viewModel.type.symbol)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let rating = viewModel.rating, rating > 0 {
                    Label(String(format: "%.1f", rating), systemImage: "star.fill")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
        }
        .padding(.horizontal)
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
            actionButton(title: "À voir", systemImage: "bookmark") {
                await viewModel.addToWatchlist()
            }
        }
        .padding(.horizontal)
    }

    private func actionButton(title: String, systemImage: String, active: Bool = false,
                              tint: Color = .accentColor, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage).font(.title3)
                Text(title).font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(active ? tint.opacity(0.15) : Color(.secondarySystemBackground))
            .foregroundStyle(active ? tint : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // ── Saisons / épisodes ────────────────────────────────────────────────

    private var seasonsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Saisons")
                .font(.headline)
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
        let expanded = viewModel.expandedSeason == number

        VStack(spacing: 0) {
            Button {
                Task { await viewModel.toggleSeason(number) }
            } label: {
                HStack(spacing: 12) {
                    PosterImage(path: season.posterPath)
                        .frame(width: 46, height: 69)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(season.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("\(season.episodeCount ?? 0) épisodes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if viewModel.seasonEpisodes[number] != nil {
                            let total = viewModel.seasonEpisodes[number]?.count ?? 0
                            let seen = viewModel.seenCount(inSeason: number)
                            ProgressView(value: total > 0 ? Double(seen) / Double(total) : 0)
                                .tint(.green)
                            Text("\(seen)/\(total) vus")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                }
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)

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
                Button {
                    Task { await viewModel.toggleSeasonSeen(season) }
                } label: {
                    let allSeen = viewModel.isSeasonFullySeen(season)
                    Label(allSeen ? "Tout marquer non vu" : "Tout marquer vu",
                          systemImage: allSeen ? "checkmark.circle.fill" : "checkmark.circle")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(allSeen ? .green : .accentColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                }
                .buttonStyle(.plain)

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
                    .foregroundStyle(seen ? .green : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
    }

    // ── Bandes-annonces ───────────────────────────────────────────────────

    private var trailersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bandes-annonces")
                .font(.headline)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(viewModel.trailers) { video in
                        Button {
                            if let url = TMDBService.youtubeWatch(video.key) { openURL(url) }
                        } label: {
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
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // ── Distribution ──────────────────────────────────────────────────────

    private var castSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Distribution")
                .font(.headline)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(viewModel.cast, id: \.stableId) { person in
                        personCard(name: person.name, role: person.character,
                                   profilePath: person.profilePath)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // ── Équipe ────────────────────────────────────────────────────────────

    private var crewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Équipe technique")
                .font(.headline)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(viewModel.crew, id: \.stableId) { person in
                        personCard(name: person.name, role: person.localizedJob,
                                   profilePath: person.profilePath)
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
            Text("Similaires")
                .font(.headline)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(viewModel.similar) { item in
                        NavigationLink(value: MediaRoute(tmdbId: item.id, type: item.mediaType)) {
                            MediaCard(posterPath: item.posterPath,
                                      title: item.displayTitle,
                                      subtitle: item.year)
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
                    Text(genre.name)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
        }
    }
}
