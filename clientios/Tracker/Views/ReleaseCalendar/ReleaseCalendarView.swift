//
//  ReleaseCalendarView.swift
//  Tracker
//

import SwiftUI

struct ReleaseCalendarView: View {
    @State private var viewModel = ReleaseCalendarViewModel()

    var body: some View {
        List {
            if viewModel.trackedCount == 0 && !viewModel.isLoading {
                ContentUnavailableView("Aucun média suivi", systemImage: "bell", description: Text("Ajoutez un film ou une série depuis sa fiche détail."))
            } else if viewModel.items.isEmpty && !viewModel.isLoading {
                ContentUnavailableView("Aucune sortie à venir", systemImage: "calendar", description: Text("Les médias suivis sont enregistrés, mais TMDB ne remonte pas encore de prochaine date."))
            } else {
                ForEach(viewModel.items) { item in
                    NavigationLink(value: MediaRoute(tmdbId: item.tmdbId, type: item.type)) {
                        releaseRow(item)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task { await viewModel.remove(item) }
                        } label: {
                            Label("Ne plus suivre", systemImage: "bell.slash")
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Sorties")
        .background(Color.appBackground.ignoresSafeArea())
        .overlay {
            if viewModel.isLoading && viewModel.items.isEmpty {
                ProgressView()
            }
        }
        .errorToast($viewModel.errorMessage)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.load(forceRefresh: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load(forceRefresh: true) }
    }

    private func releaseRow(_ item: ReleaseCalendarItem) -> some View {
        HStack(spacing: 12) {
            PosterImage(path: item.posterPath)
                .frame(width: 46, height: 69)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.kind.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tint)
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(DateOnlyFormatter.display(item.date))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack { ReleaseCalendarView() }
}
