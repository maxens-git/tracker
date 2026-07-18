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
    @State private var editorConfig: ListEditorConfig?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                controls
                if let list = viewModel.selectedList { listBar(list) }
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
        .sheet(item: $editorConfig) { config in
            TheaterListEditor(config: config) { name, codes in
                await viewModel.saveList(id: config.listId, name: name, codes: codes)
            }
        }
    }

    // ── Contrôles (liste + date) ──────────────────────────────────────────

    private var controls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                listPicker
                Spacer(minLength: 0)
                if !viewModel.isAdhoc {
                    Button {
                        editorConfig = ListEditorConfig(list: viewModel.selectedList)
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .accessibilityLabel("Modifier la liste")
                }
                Button {
                    editorConfig = ListEditorConfig(list: nil)
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Nouvelle liste")
            }

            if viewModel.isAdhoc {
                HStack(spacing: 8) {
                    Image(systemName: "building.2").foregroundStyle(.secondary)
                    TextField("Code cinéma (ex. P0057)", text: $viewModel.adhocTheater)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit { Task { await viewModel.load() } }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.appSurface, in: RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                    .strokeBorder(Color.appStroke, lineWidth: 1))
            }

            dateControls
        }
        .padding(14)
        .cinemaCard()
    }

    private var listPicker: some View {
        Menu {
            Picker("Liste", selection: Binding(
                get: { viewModel.selectedListId },
                set: { viewModel.selectList($0) }
            )) {
                ForEach(viewModel.lists) { list in
                    Text(list.isDefault ? "★ \(list.name)" : list.name).tag(Optional(list.id))
                }
                Text("Cinéma unique…").tag(Optional<Int>.none)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "list.bullet")
                Text(viewModel.selectedList?.name ?? "Cinéma unique")
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

    // ── Barre de liste (salles + actions) ─────────────────────────────────

    private func listBar(_ list: TheaterList) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(list.items, id: \.code) { item in
                        Text(viewModel.codeLabel(item.code))
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .background(Color.appSurface, in: Capsule())
                            .overlay(Capsule().strokeBorder(Color.appStroke, lineWidth: 1))
                    }
                }
            }

            HStack(spacing: 14) {
                if list.isDefault {
                    Label("par défaut", systemImage: "star.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.appGold)
                } else {
                    Button {
                        Task { await viewModel.setDefaultSelected() }
                    } label: {
                        Label("Définir par défaut", systemImage: "star")
                            .font(.caption.weight(.medium))
                    }
                }
                Spacer(minLength: 0)
                Button(role: .destructive) {
                    Task { await viewModel.deleteSelected() }
                } label: {
                    Label("Supprimer", systemImage: "trash")
                        .font(.caption.weight(.medium))
                }
            }
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
        } else if viewModel.loaded && viewModel.mergedMovies.isEmpty {
            ContentUnavailableView(
                "Aucune séance",
                systemImage: "ticket",
                description: Text(viewModel.isAdhoc
                    ? "Rien à l'affiche ce jour-là. Vérifiez le code cinéma (ex. P0057)."
                    : "Rien à l'affiche ce jour-là.")
            )
            .frame(minHeight: 240)
        } else {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.mergedMovies) { movie in
                    MovieCard(movie: movie, showTheaterName: !viewModel.isAdhoc || movie.byTheater.count > 1)
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
                .font(.subheadline.weight(.bold).monospacedDigit())
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
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
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

// MARK: - Éditeur de liste de cinémas

/// Contexte d'ouverture de l'éditeur (Identifiable pour `.sheet(item:)`).
struct ListEditorConfig: Identifiable {
    let id = UUID()
    let listId: Int?
    let name: String
    let codes: [String]

    init(list: TheaterList?) {
        self.listId = list?.id
        self.name = list?.name ?? ""
        self.codes = list?.codes ?? []
    }
}

private struct TheaterListEditor: View {
    let config: ListEditorConfig
    /// Retourne true si l'enregistrement a réussi (ferme alors la feuille).
    let onSave: (_ name: String, _ codes: [String]) async -> Bool

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var codes: [String]
    @State private var codeInput = ""
    @State private var saving = false
    @State private var errorMessage: String?

    // Un code salle Allociné valide : une lettre suivie de 3 à 5 chiffres (ex. P0057).
    private static let codePattern = try! NSRegularExpression(pattern: "^[A-Z][0-9]{3,5}$")

    init(config: ListEditorConfig, onSave: @escaping (_ name: String, _ codes: [String]) async -> Bool) {
        self.config = config
        self.onSave = onSave
        _name = State(initialValue: config.name)
        _codes = State(initialValue: config.codes)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nom") {
                    TextField("Mes cinémas", text: $name)
                }

                Section("Cinémas (codes Allociné)") {
                    HStack {
                        TextField("P0057", text: $codeInput)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .onSubmit(addCode)
                        Button("Ajouter", action: addCode)
                            .disabled(codeInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }

                    ForEach(codes, id: \.self) { code in
                        Text(code)
                    }
                    .onDelete { codes.remove(atOffsets: $0) }

                    if codes.isEmpty {
                        Text("Ajoutez au moins un cinéma par son code (ex. P0057, C0159).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(config.listId == nil ? "Nouvelle liste" : "Modifier la liste")
            .navigationBarTitleDisplayMode(.inline)
            .errorToast($errorMessage)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer", action: save)
                        .disabled(!canSave || saving)
                }
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !codes.isEmpty
    }

    private func addCode() {
        let code = codeInput.trimmingCharacters(in: .whitespaces).uppercased()
        guard !code.isEmpty else { return }
        let range = NSRange(code.startIndex..., in: code)
        guard Self.codePattern.firstMatch(in: code, range: range) != nil else {
            errorMessage = "Code cinéma invalide (ex. P0057)."
            return
        }
        if !codes.contains(code) { codes.append(code) }
        codeInput = ""
    }

    private func save() {
        guard canSave, !saving else { return }
        saving = true
        Task {
            let ok = await onSave(name.trimmingCharacters(in: .whitespaces), codes)
            saving = false
            if ok { dismiss() }
        }
    }
}

#Preview {
    NavigationStack { ShowtimesView() }
}
