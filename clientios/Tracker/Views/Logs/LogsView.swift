//
//  LogsView.swift
//  Tracker
//
//  Journal système : liste paginée (« Voir plus » automatique au défilement),
//  filtre par niveau, recherche texte, rafraîchissement et vidage.
//

import SwiftUI

struct LogsView: View {
    @State private var viewModel = LogsViewModel()

    var body: some View {
        // Toujours dans un ScrollView (même vide) pour que `.refreshable` reste actif.
        ScrollView {
            if viewModel.logs.isEmpty {
                statusView.frame(minHeight: 340)
            } else {
                feed
            }
        }
        .background(Color.appBackground)
        .navigationTitle("Logs")
        .navigationBarTitleDisplayMode(.inline)
        .errorToast($viewModel.errorMessage)
        .searchable(text: $viewModel.search, prompt: "Message, catégorie, route…")
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .onSubmit(of: .search) { Task { await viewModel.applyFilters() } }
        .onChange(of: viewModel.search) { _, newValue in
            if newValue.isEmpty { Task { await viewModel.applyFilters() } }
        }
        .onChange(of: viewModel.level) { Task { await viewModel.applyFilters() } }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Niveau", selection: $viewModel.level) {
                        ForEach(LogLevelFilter.allCases) { level in
                            Text(level.label).tag(level)
                        }
                    }
                } label: {
                    Label("Niveau", systemImage: viewModel.level == .all
                          ? "line.3.horizontal.decrease.circle"
                          : "line.3.horizontal.decrease.circle.fill")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    Task { await viewModel.clear() }
                } label: {
                    if viewModel.isClearing {
                        ProgressView()
                    } else {
                        Label("Vider les logs", systemImage: "trash")
                    }
                }
                .disabled(viewModel.isClearing || viewModel.isLoading)
            }
        }
        .task { await viewModel.loadInitial() }
        .refreshable { await viewModel.refresh() }
    }

    // ── Liste ─────────────────────────────────────────────────────────────────

    private var feed: some View {
        LazyVStack(alignment: .leading, spacing: 10) {
            if viewModel.totalCount > 0 {
                Text("\(viewModel.totalCount) entrée\(viewModel.totalCount > 1 ? "s" : "")")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            ForEach(viewModel.logs) { log in
                LogRow(log: log)
                    .onAppear {
                        if log.id == viewModel.logs.last?.id {
                            Task { await viewModel.loadMore() }
                        }
                    }
            }

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 24)
    }

    @ViewBuilder
    private var statusView: some View {
        if viewModel.isLoading {
            ProgressView().frame(maxWidth: .infinity)
        } else if let error = viewModel.errorMessage {
            ContentUnavailableView("Erreur", systemImage: "doc.text.magnifyingglass", description: Text(error))
        } else {
            ContentUnavailableView("Aucun log", systemImage: "doc.text.magnifyingglass",
                                   description: Text("Le journal système est vide."))
        }
    }
}

// MARK: - Ligne de log

private struct LogRow: View {
    let log: SystemLog
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(log.level.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(levelColor, in: Capsule())

                Spacer(minLength: 8)

                if let code = log.statusCode {
                    Text("\(code)")
                        .font(.caption2.weight(.bold).monospacedDigit())
                        .foregroundStyle(statusColor(code))
                }

                Text(dateText)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }

            Text(log.message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(log.category)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            if log.method != nil || log.path != nil || log.elapsedMs != nil {
                httpLine
            }

            if let exception = log.exception, !exception.isEmpty {
                DisclosureGroup(isExpanded: $expanded) {
                    Text(exception)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                } label: {
                    Text("Exception")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }

            if let trace = log.traceId, !trace.isEmpty {
                Text("Trace \(trace)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }

    private var httpLine: some View {
        HStack(spacing: 6) {
            if let method = log.method, !method.isEmpty {
                Text(method)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            if let path = log.path, !path.isEmpty {
                Text(path)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            if let ms = log.elapsedMs {
                Text("\(Int(ms.rounded())) ms")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // ── Présentation ────────────────────────────────────────────────────────

    private var levelColor: Color {
        switch log.level.lowercased() {
        case "critical":        return .purple
        case "error":           return .red
        case "warning":         return .orange
        case "information":     return .blue
        case "debug", "trace":  return .gray
        default:                return .gray
        }
    }

    private func statusColor(_ code: Int) -> Color {
        switch code {
        case 200..<300: return .green
        case 300..<400: return .blue
        case 400..<500: return .orange
        default:        return .red
        }
    }

    private var dateText: String {
        guard let date = log.createdAt else { return "" }
        return Self.formatter.string(from: date)
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "dd/MM HH:mm:ss"
        return formatter
    }()
}

#Preview {
    NavigationStack { LogsView() }
}
