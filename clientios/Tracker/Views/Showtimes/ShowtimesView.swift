//
//  ShowtimesView.swift
//  Tracker
//
//  Séances de cinéma : programme d'une liste de salles (ou d'un cinéma unique)
//  pour une date, regroupé par film — chaque séance rattachée à sa salle.
//  Listes sauvegardées, liste par défaut, navigation par date (pas de passé).
//

import SwiftUI

// Étiquettes compactes des formats Allociné (ex. DOLBY_CINEMA → « Dolby »).
private let formatLabels: [String: String] = [
    "IMAX": "IMAX", "IMAX_3D": "IMAX 3D", "DOLBY_CINEMA": "Dolby", "DOLBY_ATMOS": "Atmos",
    "ICE": "ICE", "4DX": "4DX", "SCREENX": "ScreenX", "3D": "3D",
]

private func formatLabel(_ format: String) -> String {
    formatLabels[format] ?? format.replacingOccurrences(of: "_", with: " ")
}

struct ShowtimesView: View {
    @State private var viewModel = ShowtimesViewModel()
    @State private var editorOpen = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                controls
                dayLine
                content
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Séances")
        .navigationBarTitleDisplayMode(.inline)
        .errorToast($viewModel.errorMessage)
        .task { await viewModel.start() }
        .onChange(of: viewModel.pickedDate) { Task { await viewModel.load() } }
        .sheet(isPresented: $editorOpen) {
            FavoritesEditor(viewModel: viewModel)
        }
    }

    // ── Contrôles (cinémas + date) ────────────────────────────────────────

    private var controls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                cinemasMenu
                Spacer(minLength: 0)
                Button {
                    editorOpen = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Ajouter un cinéma")
            }

            dateControls
        }
        .padding(14)
        .cinemaCard()
    }

    // Dropdown des cinémas enregistrés : chacun cochable (affiché ou non).
    private var cinemasMenu: some View {
        Menu {
            if viewModel.favorites.isEmpty {
                Text("Aucun cinéma enregistré")
            } else {
                ForEach(viewModel.favorites) { fav in
                    Toggle(isOn: Binding(
                        get: { fav.isActive },
                        set: { _ in viewModel.toggleActive(fav) }
                    )) {
                        Text(viewModel.codeLabel(fav.code))
                    }
                }
            }
            Divider()
            Button {
                editorOpen = true
            } label: {
                Label("Gérer les cinémas", systemImage: "slider.horizontal.3")
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "building.2")
                Text(cinemasMenuLabel)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Image(systemName: "chevron.down").font(.caption2)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.appSurface, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.appStroke, lineWidth: 1))
        }
    }

    private var cinemasMenuLabel: String {
        if viewModel.favorites.isEmpty { return "Cinémas" }
        return "\(viewModel.activeCount)/\(viewModel.favorites.count) cinémas"
    }

    private var dateControls: some View {
        HStack(spacing: 10) {
            Button { viewModel.shiftDay(-1) } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(!viewModel.canGoPrev)

            DatePicker("Date", selection: $viewModel.pickedDate, in: viewModel.today...,
                       displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)

            Button { viewModel.shiftDay(1) } label: {
                Image(systemName: "chevron.right")
            }

            Spacer(minLength: 0)
        }
    }

    // ── Ligne du jour ─────────────────────────────────────────────────────

    private var dayLine: some View {
        HStack(spacing: 8) {
            Text(dayLabel).font(.display(18))
            if Calendar.current.isDateInToday(viewModel.pickedDate) {
                Text("aujourd'hui")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.appBackground)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.appGold, in: Capsule())
            }
            Spacer(minLength: 0)
        }
    }

    private var dayLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEEE d MMMM"
        return f.string(from: viewModel.pickedDate).capitalized
    }

    // ── Contenu (films) ───────────────────────────────────────────────────

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.programs.isEmpty {
            ProgressView().frame(maxWidth: .infinity, minHeight: 240)
        } else if viewModel.loaded && viewModel.favorites.isEmpty {
            ContentUnavailableView {
                Label("Aucun cinéma enregistré", systemImage: "building.2")
            } description: {
                Text("Ajoutez vos cinémas pour retrouver leurs séances ici.")
            } actions: {
                Button("Ajouter un cinéma") { editorOpen = true }
                    .buttonStyle(.borderedProminent)
            }
            .frame(minHeight: 240)
        } else if viewModel.loaded && viewModel.activeCount == 0 {
            ContentUnavailableView(
                "Aucun cinéma coché",
                systemImage: "checklist",
                description: Text("Cochez au moins un cinéma pour afficher ses séances.")
            )
            .frame(minHeight: 240)
        } else if viewModel.loaded && viewModel.mergedMovies.isEmpty {
            ContentUnavailableView(
                "Aucune séance",
                systemImage: "ticket",
                description: Text("Rien à l'affiche ce jour-là.")
            )
            .frame(minHeight: 240)
        } else {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.mergedMovies) { movie in
                    MovieCard(movie: movie, showTheaterName: true)
                }
            }
        }
    }
}

// MARK: - Carte film

private struct MovieCard: View {
    let movie: MergedMovie
    let showTheaterName: Bool

    var body: some View {
        // En-tête (affiche + titre) séparé des séances : les horaires occupent
        // ensuite toute la largeur de la carte plutôt que la colonne étroite à
        // droite de l'affiche — moins de retours à la ligne, cartes bien plus courtes.
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                AllocinePoster(url: movie.poster)
                    .frame(width: 56, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(movie.title)
                        .font(.display(17))
                        .fixedSize(horizontal: false, vertical: true)

                    if movie.runtime != nil || !movie.genres.isEmpty {
                        Text([movie.runtime, movie.genres.joined(separator: ", ")]
                            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }

            ForEach(movie.byTheater) { group in
                theaterGroup(group)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cinemaCard()
    }

    private func theaterGroup(_ group: MovieTheaterShows) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if showTheaterName {
                Label(group.theater.label, systemImage: "mappin.and.ellipse")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            FlowRow(spacing: 6) {
                ForEach(group.shows) { show in
                    ShowChip(show: show)
                }
            }
        }
    }
}

// MARK: - Chip séance

private struct ShowChip: View {
    let show: Showtime

    var body: some View {
        if let urlString = show.ticketingUrl, let url = URL(string: urlString) {
            Link(destination: url) { chip }
        } else {
            chip.opacity(0.55)
        }
    }

    private var chip: some View {
        HStack(spacing: 5) {
            Text(show.time)
                .font(.title3.weight(.bold).monospacedDigit())
            if let version = show.version {
                tag(version, color: .secondary, bg: Color.appStroke)
            }
            ForEach(show.formats, id: \.self) { fmt in
                tag(formatLabel(fmt), color: Color.appGold, bg: Color.appGold.opacity(0.16))
            }
            if show.isPreview {
                tag("AP", color: .red, bg: Color.red.opacity(0.14))
            }
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(show.isPreview ? Color.appGold.opacity(0.5) : Color.appStroke,
                          style: StrokeStyle(lineWidth: 1, dash: show.isPreview ? [3] : [])))
    }

    private func tag(_ text: String, color: Color, bg: Color) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9.5, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(bg, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

// MARK: - Affiche Allociné (URL complète, hors TMDB)

private struct AllocinePoster: View {
    let url: String?

    var body: some View {
        Color(.secondarySystemBackground)
            .overlay {
                RemoteImage(url: url.flatMap { URL(string: $0) }) {
                    Image(systemName: "film")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
    }
}

// MARK: - Gestion des cinémas enregistrés (ajout / retrait)

private struct FavoritesEditor: View {
    let viewModel: ShowtimesViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var codeInput = ""
    @State private var adding = false

    // Un code salle Allociné valide : une lettre suivie de 3 à 5 chiffres (ex. P0057).
    private static let codePattern = try! NSRegularExpression(pattern: "^[A-Z][0-9]{3,5}$")

    var body: some View {
        NavigationStack {
            Form {
                Section("Ajouter un cinéma (code Allociné)") {
                    HStack {
                        TextField("P0057", text: $codeInput)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .onSubmit(addCode)
                        Button("Ajouter", action: addCode)
                            .disabled(codeInput.trimmingCharacters(in: .whitespaces).isEmpty || adding)
                    }
                }

                Section("Cinémas enregistrés") {
                    ForEach(viewModel.favorites) { fav in
                        Text(viewModel.codeLabel(fav.code))
                    }
                    .onDelete { offsets in
                        let toRemove = offsets.map { viewModel.favorites[$0] }
                        Task { for fav in toRemove { await viewModel.removeFavorite(fav) } }
                    }

                    if viewModel.favorites.isEmpty {
                        Text("Ajoutez un cinéma par son code (ex. P0057, C0159).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Mes cinémas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    private func addCode() {
        let code = codeInput.trimmingCharacters(in: .whitespaces).uppercased()
        guard !code.isEmpty else { return }
        let range = NSRange(code.startIndex..., in: code)
        guard Self.codePattern.firstMatch(in: code, range: range) != nil else {
            viewModel.errorMessage = "Code cinéma invalide (ex. P0057)."
            return
        }
        adding = true
        Task {
            let ok = await viewModel.addFavorite(code: code)
            if ok { codeInput = "" }
            adding = false
        }
    }
}

#Preview {
    NavigationStack { ShowtimesView() }
}
