//
//  ActivityView.swift
//  Tracker
//
//  Flux des dernières actions de l'utilisateur (vu / aimé / ajouts et retraits de listes).
//

import SwiftUI

struct ActivityView: View {
    @State private var viewModel = ActivityViewModel()

    var body: some View {
        Group {
            if viewModel.entries.isEmpty {
                placeholder
            } else {
                list
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Activité")
        .task { await viewModel.loadInitial() }
        .refreshable { await viewModel.reload() }
    }

    private var list: some View {
        List {
            ForEach(viewModel.entries) { entry in
                ActivityRow(entry: entry)
                    .listRowBackground(Color.appSurface)
                    .onAppear {
                        if entry.id == viewModel.entries.last?.id {
                            Task { await viewModel.loadMore() }
                        }
                    }
            }

            if viewModel.isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private var placeholder: some View {
        if viewModel.isLoading {
            ProgressView().frame(maxWidth: .infinity, minHeight: 400)
        } else if let error = viewModel.errorMessage {
            ContentUnavailableView("Erreur", systemImage: "clock.arrow.circlepath", description: Text(error))
        } else {
            ContentUnavailableView("Aucune activité",
                                   systemImage: "clock.arrow.circlepath",
                                   description: Text("Vos dernières actions apparaîtront ici."))
        }
    }
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
                PosterImage(path: activity.posterPath, size: "w185")
                    .frame(width: 40, height: 60)

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Image(systemName: style.icon)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(style.tint)
                        Text(label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                Text(relativeTime)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
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
        case .unknown: return ""
        }
    }

    private var style: ActivityStyle {
        switch activity.type {
        case .seen:            return ActivityStyle(icon: "checkmark.circle.fill", tint: .accentColor)
        case .unseen:          return ActivityStyle(icon: "arrow.uturn.backward.circle.fill", tint: .secondary)
        case .liked:           return ActivityStyle(icon: "heart.fill", tint: .pink)
        case .unliked:         return ActivityStyle(icon: "heart.slash.fill", tint: .pink)
        case .addedToList:     return ActivityStyle(icon: "plus.circle.fill", tint: .yellow)
        case .removedFromList: return ActivityStyle(icon: "minus.circle.fill", tint: .red)
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
