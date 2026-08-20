//
//  ActivityView.swift
//  Tracker
//
//  Flux des dernières actions de l'utilisateur (vu / aimé / ajouts et retraits
//  de listes), en liste groupée avec un en-tête de section par période.
//

import SwiftUI

struct ActivityView: View {
    @State private var viewModel = ActivityViewModel()

    var body: some View {
        List {
            ForEach(sections) { section in
                Section(section.title) {
                    ForEach(section.entries) { entry in
                        NavigationLink {
                            MediaDetailView(tmdbId: entry.activity.tmdbId, type: entry.activity.type2)
                        } label: {
                            ActivityRow(entry: entry)
                        }
                        .onAppear {
                            if entry.id == viewModel.entries.last?.id {
                                Task { await viewModel.loadMore() }
                            }
                        }
                    }
                }
            }

            if viewModel.isLoading && !viewModel.entries.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
            }
        }
        .navigationTitle("Activité")
        .errorToast($viewModel.errorMessage)
        .overlay {
            if viewModel.entries.isEmpty { statusView }
        }
        .task { await viewModel.loadInitial() }
        .refreshable { await viewModel.reload() }
    }

    @ViewBuilder
    private var statusView: some View {
        if viewModel.isLoading {
            ProgressView()
        } else if let error = viewModel.errorMessage {
            ContentUnavailableView("Erreur", systemImage: "clock.arrow.circlepath", description: Text(error))
        } else {
            ContentUnavailableView("Aucune activité",
                                   systemImage: "clock.arrow.circlepath",
                                   description: Text("Vos dernières actions apparaîtront ici."))
        }
    }

    // ── Regroupement par période ────────────────────────────────────────────

    /// Découpe le flux (déjà trié du plus récent au plus ancien) en sections par période.
    private var sections: [ActivitySection] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var result: [ActivitySection] = []

        for entry in viewModel.entries {
            let date = entry.activity.createdAt ?? Date()
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: today).day ?? 0
            let bucket: (order: Int, title: String) = switch days {
            case ..<1:   (0, "Aujourd'hui")
            case 1:      (1, "Hier")
            case 2...6:  (2, "Cette semaine")
            case 7...30: (3, "Ce mois-ci")
            default:     (4, "Plus tôt")
            }

            if let last = result.last, last.id == bucket.order {
                result[result.count - 1].entries.append(entry)
            } else {
                result.append(ActivitySection(id: bucket.order, title: bucket.title, entries: [entry]))
            }
        }
        return result
    }
}

/// Une période du flux (toutes les entrées d'« Aujourd'hui », etc.).
private struct ActivitySection: Identifiable {
    let id: Int
    let title: String
    var entries: [ActivityEntry]
}

// MARK: - Ligne d'activité

/// Icône et couleur de pastille d'un type d'action.
private struct ActivityStyle {
    let icon: String
    let tint: Color
}

private struct ActivityRow: View {
    let entry: ActivityEntry

    private var activity: Activity { entry.activity }

    var body: some View {
        HStack(spacing: 12) {
            poster

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Text(relativeTime)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    /// Affiche + pastille d'action colorée incrustée en bas à droite.
    private var poster: some View {
        PosterImage(path: entry.posterPath, size: "w185")
            .frame(width: 44, height: 66)
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: style.icon)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(style.tint))
                    .overlay(Circle().stroke(Color.appSurface, lineWidth: 2))
                    .offset(x: 5, y: 5)
            }
    }

    // ── Présentation ────────────────────────────────────────────────────────

    private var label: String {
        switch activity.type {
        case .seen: return "Marqué comme vu"
        case .unseen: return "Marqué comme non vu"
        case .liked: return "Ajouté aux j'aime"
        case .unliked: return "Retiré des j'aime"
        case .addedToList: return "Ajouté à « \(activity.listName ?? "une liste") »"
        case .removedFromList: return "Retiré de « \(activity.listName ?? "une liste") »"
        case .seasonSeen: return "Saison \(activity.seasonNumber ?? 0) vue"
        case .seasonUnseen: return "Saison \(activity.seasonNumber ?? 0) non vue"
        case .episodeSeen: return "Épisode S\(activity.seasonNumber ?? 0)E\(activity.episodeNumber ?? 0) vu"
        case .episodeUnseen: return "Épisode S\(activity.seasonNumber ?? 0)E\(activity.episodeNumber ?? 0) non vu"
        case .unknown: return ""
        }
    }

    private var style: ActivityStyle {
        switch activity.type {
        case .seen, .seasonSeen, .episodeSeen:
            return ActivityStyle(icon: "checkmark", tint: .green)
        case .unseen, .seasonUnseen, .episodeUnseen:
            return ActivityStyle(icon: "arrow.uturn.backward", tint: .gray)
        case .liked:           return ActivityStyle(icon: "heart.fill", tint: .pink)
        case .unliked:         return ActivityStyle(icon: "heart.slash.fill", tint: .pink)
        case .addedToList:     return ActivityStyle(icon: "plus", tint: .accentColor)
        case .removedFromList: return ActivityStyle(icon: "minus", tint: .red)
        case .unknown:         return ActivityStyle(icon: "circle.fill", tint: .gray)
        }
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private var relativeTime: String {
        guard let date = activity.createdAt else { return "" }
        return Self.relativeFormatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    NavigationStack { ActivityView() }
}
