//
//  WatchHistorySheet.swift
//  Tracker
//
//  Historique des visionnages d'un film / d'une série ou d'un épisode :
//  liste datée (balayer pour supprimer) et ajout d'un visionnage à une date
//  choisie, pour logger un revisionnage passé.
//

import SwiftUI

/// Ce dont on consulte l'historique : un média entier ou un épisode précis.
enum WatchHistoryTarget: Identifiable, Hashable {
    /// Les métadonnées servent au backend s'il doit créer le média à l'ajout.
    case media(tmdbId: Int, type: MediaType, posterPath: String?, runtime: Int?, title: String, genres: [TMDBGenre])
    case episode(showTmdbId: Int, season: Int, episode: Int)

    var id: String {
        switch self {
        case let .media(tmdbId, type, _, _, _, _): "\(type.rawValue)-\(tmdbId)"
        case let .episode(showTmdbId, season, episode): "tv-\(showTmdbId)-\(season)-\(episode)"
        }
    }
}

struct WatchHistorySheet: View {
    let target: WatchHistoryTarget
    /// Appelé avec le nouveau nombre de visionnages après chaque ajout / suppression.
    let onCountChange: (Int) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var events: [WatchEvent] = []
    @State private var isLoading = true
    @State private var isAdding = false
    @State private var newDate = Date()
    @State private var errorMessage: String?

    private let api = APIService.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DatePicker("Date", selection: $newDate, in: ...Date(), displayedComponents: .date)
                    Button {
                        Task { await add() }
                    } label: {
                        HStack {
                            Label("Ajouter un visionnage", systemImage: "plus.circle.fill")
                            if isAdding {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isAdding)
                }

                Section {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else if events.isEmpty {
                        Text("Aucun visionnage enregistré.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(events) { event in
                            Label {
                                Text(event.watchedAt.formatted(.dateTime.day().month(.wide).year()
                                    .locale(Locale(identifier: "fr_FR"))))
                            } icon: {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.appGreen)
                            }
                        }
                        .onDelete { offsets in
                            Task { await remove(offsets.map { events[$0] }) }
                        }
                    }
                } header: {
                    if events.count > 1 {
                        Text("\(events.count) visionnages")
                    }
                } footer: {
                    if !events.isEmpty {
                        Text("Balayez un visionnage vers la gauche pour le supprimer.")
                    }
                }
            }
            .navigationTitle(isEpisode ? "Visionnages de l'épisode" : "Visionnages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
            .errorToast($errorMessage)
            .task { await load() }
        }
        .presentationDetents([.medium, .large])
    }

    private var isEpisode: Bool {
        if case .episode = target { return true }
        return false
    }

    private func load() async {
        isLoading = true
        do {
            let loaded: [WatchEvent]
            switch target {
            case let .media(tmdbId, type, _, _, _, _):
                loaded = try await api.watches(tmdbId: tmdbId, type: type)
            case let .episode(showTmdbId, season, episode):
                loaded = try await api.episodeWatches(showTmdbId: showTmdbId, season: season, episode: episode)
            }
            events = sorted(loaded)
        } catch {
            if !error.isCancellation { errorMessage = error.localizedDescription }
        }
        isLoading = false
    }

    private func add() async {
        guard !isAdding else { return }
        isAdding = true
        defer { isAdding = false }
        do {
            let event: WatchEvent
            switch target {
            case let .media(tmdbId, type, posterPath, runtime, title, genres):
                event = try await api.addWatch(tmdbId: tmdbId, type: type, watchedAt: newDate,
                                               posterPath: posterPath, runtime: runtime,
                                               title: title, genres: genres)
            case let .episode(showTmdbId, season, episode):
                event = try await api.addEpisodeWatch(showTmdbId: showTmdbId, season: season,
                                                      episode: episode, watchedAt: newDate)
            }
            events = sorted(events + [event])
            newDate = Date()
            Haptics.success()
            await onCountChange(events.count)
        } catch {
            if !error.isCancellation { errorMessage = error.localizedDescription }
            Haptics.error()
        }
    }

    private func remove(_ toRemove: [WatchEvent]) async {
        for event in toRemove {
            do {
                switch target {
                case let .media(tmdbId, type, _, _, _, _):
                    try await api.deleteWatch(tmdbId: tmdbId, type: type, watchId: event.id)
                case let .episode(showTmdbId, season, episode):
                    try await api.deleteEpisodeWatch(showTmdbId: showTmdbId, season: season,
                                                     episode: episode, watchId: event.id)
                }
                events.removeAll { $0.id == event.id }
                Haptics.impact(.light)
            } catch {
                if !error.isCancellation { errorMessage = error.localizedDescription }
                Haptics.error()
            }
        }
        await onCountChange(events.count)
    }

    private func sorted(_ events: [WatchEvent]) -> [WatchEvent] {
        events.sorted { ($0.watchedAt, $0.id) > ($1.watchedAt, $1.id) }
    }
}
