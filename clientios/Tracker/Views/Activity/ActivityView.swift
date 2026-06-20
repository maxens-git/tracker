//
//  ActivityView.swift
//  Tracker
//
//  Flux des dernières actions de l'utilisateur (vu / aimé / ajouts et retraits de listes),
//  regroupé par période (Aujourd'hui, Hier, …) en cartes.
//

import SwiftUI

struct ActivityView: View {
    @State private var viewModel = ActivityViewModel()

    var body: some View {
        // Toujours dans un ScrollView (même vide) : le `.refreshable` reste actif
        // dans tous les états et ne s'auto-annule pas.
        ScrollView {
            if viewModel.entries.isEmpty {
                statusView.frame(minHeight: 420)
            } else {
                feed
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Activité")
        .errorToast($viewModel.errorMessage)
        .task { await viewModel.loadInitial() }
        .refreshable { await viewModel.reload() }
    }

    private var feed: some View {
        LazyVStack(alignment: .leading, spacing: 20, pinnedViews: [.sectionHeaders]) {
            ForEach(sections) { section in
                Section {
                    card(for: section)
                } header: {
                    sectionHeader(section.title)
                }
            }

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
        .padding(.bottom, 24)
    }

    /// Carte groupée contenant les lignes d'une période, séparées par des filets.
    private func card(for section: ActivitySection) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(section.entries.enumerated()), id: \.element.id) { index, entry in
                ActivityRow(entry: entry)
                    .onAppear {
                        if entry.id == viewModel.entries.last?.id {
                            Task { await viewModel.loadMore() }
                        }
                    }

                if index < section.entries.count - 1 {
                    Divider().padding(.leading, 72)
                }
            }
        }
        .cinemaCard()
        .padding(.horizontal)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
            .padding(.horizontal)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.appBackground)
    }

    @ViewBuilder
    private var statusView: some View {
        if viewModel.isLoading {
            ProgressView().frame(maxWidth: .infinity)
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
        NavigationLink(value: MediaRoute(tmdbId: activity.tmdbId, type: activity.type2)) {
            HStack(spacing: 12) {
                poster

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Text(relativeTime)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Affiche + pastille d'action colorée incrustée en bas à droite.
    private var poster: some View {
        PosterImage(path: entry.posterPath, size: "w185")
            .frame(width: 48, height: 72)
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: style.icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 21, height: 21)
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
            return ActivityStyle(icon: "checkmark", tint: .accentColor)
        case .unseen, .seasonUnseen, .episodeUnseen:
            return ActivityStyle(icon: "arrow.uturn.backward", tint: .secondary)
        case .liked:           return ActivityStyle(icon: "heart.fill", tint: .pink)
        case .unliked:         return ActivityStyle(icon: "heart.slash.fill", tint: .pink)
        case .addedToList:     return ActivityStyle(icon: "plus", tint: .orange)
        case .removedFromList: return ActivityStyle(icon: "minus", tint: .red)
        case .unknown:         return ActivityStyle(icon: "circle.fill", tint: .secondary)
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
