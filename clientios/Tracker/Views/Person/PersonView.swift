//
//  PersonView.swift
//  Tracker
//
//  Détail d'une personne : photo, informations et filmographie.
//

import SwiftUI

struct PersonView: View {
    @State private var viewModel: PersonViewModel

    init(personId: Int) {
        _viewModel = State(initialValue: PersonViewModel(personId: personId))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if let bio = viewModel.biography, !bio.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Biographie").font(.headline)
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
                    .fill(Color(.secondarySystemBackground))
                    .overlay(Image(systemName: "person.fill").font(.largeTitle).foregroundStyle(.secondary))
            }
            .frame(width: 120, height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(viewModel.name)
                    .font(.title2.bold())
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
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
        }
    }

    // ── Filmographie ───────────────────────────────────────────────────────

    private var filmographySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filmographie")
                .font(.headline)
                .padding(.horizontal)

            MediaGrid {
                ForEach(viewModel.filmography) { item in
                    NavigationLink(value: MediaRoute(tmdbId: item.tmdbId, type: item.type)) {
                        VStack(alignment: .leading, spacing: 6) {
                            PosterImage(path: item.posterPath)
                                .aspectRatio(2.0 / 3.0, contentMode: .fit)
                                .overlay(alignment: .topTrailing) {
                                    if item.seen {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.white, .green)
                                            .padding(6)
                                    }
                                }
                            Text(item.title)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .foregroundStyle(.primary)
                            Text(item.year ?? " ")
                                .font(.caption)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxHeight: .infinity, alignment: .top)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
