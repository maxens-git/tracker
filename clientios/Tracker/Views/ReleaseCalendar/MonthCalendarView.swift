//
//  MonthCalendarView.swift
//  Tracker
//
//  Grille mensuelle « maison » (SwiftUI n'a pas de calendrier intégré) : un mois
//  navigable, une pastille sous les jours qui portent une sortie, et la sélection
//  d'un jour remontée au parent qui affiche les sorties correspondantes.
//

import SwiftUI

struct MonthCalendarView: View {
    /// N'importe quelle date du mois affiché.
    @Binding var month: Date
    /// Jour sélectionné au format `yyyy-MM-dd`.
    @Binding var selectedDay: String?
    /// Jours (`yyyy-MM-dd`) portant au moins une sortie.
    let daysWithReleases: Set<String>

    private static let weekdaySymbols = ["lun", "mar", "mer", "jeu", "ven", "sam", "dim"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2 // lundi
        calendar.locale = Locale(identifier: "fr_FR")
        return calendar
    }

    var body: some View {
        VStack(spacing: 12) {
            header
            weekdayRow
            daysGrid
        }
        .padding(12)
        .cinemaCard()
    }

    private var header: some View {
        HStack {
            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left").font(.body.weight(.semibold))
            }
            Spacer()
            Text(monthTitle)
                .font(.display(18))
            Spacer()
            Button { shiftMonth(1) } label: {
                Image(systemName: "chevron.right").font(.body.weight(.semibold))
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(Self.weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var daysGrid: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 40)
                }
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let key = DateOnlyFormatter.input.string(from: date)
        let hasRelease = daysWithReleases.contains(key)
        let isSelected = selectedDay == key
        let isToday = calendar.isDateInToday(date)

        return Button {
            selectedDay = key
        } label: {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.callout)
                    .foregroundStyle(isSelected ? Color.white : .primary)
                Circle()
                    .fill(dotColor(hasRelease: hasRelease, isSelected: isSelected))
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.accentColor)
                } else if isToday {
                    RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Color.appStroke, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func dotColor(hasRelease: Bool, isSelected: Bool) -> Color {
        guard hasRelease else { return .clear }
        return isSelected ? .white : .accentColor
    }

    // ── Calculs de mois ────────────────────────────────────────────────────────

    /// Cases du mois : `nil` en tête pour décaler le 1er sur le bon jour de semaine.
    private var daysInMonth: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let range = calendar.range(of: .day, in: .month, for: month) else { return [] }

        let firstDay = interval.start
        let weekday = calendar.component(.weekday, from: firstDay)
        let leading = (weekday - calendar.firstWeekday + 7) % 7

        var cells: [Date?] = Array(repeating: nil, count: leading)
        for offset in range {
            cells.append(calendar.date(byAdding: .day, value: offset - 1, to: firstDay))
        }
        return cells
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: month).capitalized
    }

    private func shiftMonth(_ value: Int) {
        if let next = calendar.date(byAdding: .month, value: value, to: month) {
            month = next
        }
    }
}
