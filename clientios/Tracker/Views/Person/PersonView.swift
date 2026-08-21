//
//  PersonView.swift
//  Tracker
//
//  Détail d'une personne : photo, informations et filmographie.
//

import SwiftUI

struct PersonView: View {
    @State private var viewModel: PersonViewModel
    @Environment(\.zoomNamespace) private var zoomNamespace

    init(personId: Int) {
        _viewModel = State(initialValue: PersonViewModel(personId: personId))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if let bio = viewModel.biography, !bio.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader("Biographie")
                        Text(bio).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }
                if !viewModel.filmography.isEmpty { filmographySection }
            }
            .padding(.vertical)
        }
        .navigationTitle(viewModel.name)
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if viewModel.isLoading && viewModel.person == nil {
                ProgressView()
            } else if viewModel.person == nil, let error = viewModel.errorMessage {
                ContentUnavailableView("Erreur de chargement", systemImage: "person.crop.circle.badge.exclamationmark",
                                       description: Text(error))
            }
        }
        .task { await viewModel.load() }
    }

    // ── En-tête ──────────────────────────────────────────────────────────

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            AsyncImage(url: TMDBService.profileURL(viewModel.profilePath, size: "w342")) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle()
                    .fill(Color.appPlaceholder)
                    .overlay(Image(systemName: "person.fill").font(.largeTitle).foregroundStyle(.secondary))
            }
            .frame(width: 120, height: 160)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
            .background {
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .fill(Color.appSurface)
                    .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 5)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(viewModel.name)
                    .font(.title2.weight(.bold))
                if let department = viewModel.department, !department.isEmpty {
                    Text(department)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                facts
            }
            Spacer()
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var facts: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let birthday = viewModel.birthday {
                fact(label: "Naissance",
                     value: birthday + (viewModel.age.map { " (\($0) ans)" } ?? ""))
            }
            if let deathday = viewModel.deathday {
                fact(label: "Décès", value: deathday)
            }
            if let place = viewModel.placeOfBirth, !place.isEmpty {
                fact(label: "Lieu", value: place)
            }
        }
        .padding(.top, 4)
    }

    private func fact(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
        }
    }

    // ── Filmographie ───────────────────────────────────────────────────────

    private var filmographySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Filmographie")
                .padding(.horizontal)

            MediaGrid {
                ForEach(viewModel.filmography) { item in
                    let route = MediaRoute(tmdbId: item.tmdbId, type: item.type, source: "person-\(viewModel.personId)")
                    NavigationLink(value: route) {
                        MediaCard(posterPath: item.posterPath,
                                  title: item.title,
                                  subtitle: item.year,
                                  seen: item.seen)
                            .zoomSource(route, in: zoomNamespace)
                    }
                    .buttonStyle(.pressableCard)
                }
            }
        }
    }
}
