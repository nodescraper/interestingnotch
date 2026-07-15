//
//  CalendarWidgetPageView.swift
//  InterestingNotch
//
//  Created by Codex on 2026-07-14.
//  Week-rail + agenda design: a horizontal 7-day rail (echoing the timer ruler)
//  anchors the selected day, with that day's agenda beside it. Orange accent,
//  notch-friendly wide-short layout.
//

import AppKit
import EventKit
import SwiftUI

struct CalendarWidgetPageView: View {
    let widget: Widget

    @ObservedObject var model: CalendarWidgetModel

    private let accent = Color.effectiveAccent

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Left: compact month grid.
            VStack(alignment: .leading, spacing: 8) {
                header
                monthGrid
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // Right: events, then reminders.
            agenda
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Header (month + year + month paging)

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(monthTitle)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(yearTitle)
                .font(.system(size: 15, weight: .light, design: .rounded))
                .foregroundStyle(.white.opacity(0.32))

            Spacer(minLength: 4)

            monthStepper
        }
    }

    // MARK: - Month grid

    private var monthGrid: some View {
        VStack(spacing: 3) {
            // Weekday header row.
            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.35))
                        .tracking(0.3)
                        .frame(maxWidth: .infinity)
                }
            }

            // 6 weeks × 7 days.
            ForEach(monthWeeks.indices, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(monthWeeks[row], id: \.self) { day in
                        monthDayCell(day)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func monthDayCell(_ day: Date?) -> some View {
        Group {
            if let day {
                let selected = isSameDay(day, model.selectedDate)
                let today = isSameDay(day, Date())
                let inMonth = isInDisplayedMonth(day)
                let dayNumber = Calendar.current.component(.day, from: day)

                Button {
                    Task { await model.selectDate(day) }
                } label: {
                    Text("\(dayNumber)")
                        .font(.system(size: 11, weight: selected ? .bold : .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(dayColor(selected: selected, today: today, inMonth: inMonth))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(selected ? accent : .clear))
                        .overlay(
                            Circle().strokeBorder(today && !selected ? accent.opacity(0.7) : .clear, lineWidth: 1.5)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selected)
            } else {
                Color.clear.frame(width: 22, height: 22)
            }
        }
    }

    private func dayColor(selected: Bool, today: Bool, inMonth: Bool) -> Color {
        if selected { return .white }
        if !inMonth { return .white.opacity(0.2) }
        if today { return accent }
        return .white.opacity(0.85)
    }

    private var monthStepper: some View {
        HStack(spacing: 5) {
            stepButton(symbol: "chevron.left") { shiftMonth(by: -1) }
            stepButton(symbol: "chevron.right") { shiftMonth(by: 1) }
        }
    }

    private func stepButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(accent)
                .frame(width: 22, height: 22)
                .background(accent.opacity(0.14), in: Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Agenda: events then reminders, filling the right column

    private var agenda: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Day title row.
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(selectedDayTitle)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if !isSameDay(model.selectedDate, Date()) {
                    Button {
                        Task { await model.selectDate(Date()) }
                    } label: {
                        Text("Today")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(accent)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(accent.opacity(0.14), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 8)

            if eventItems.isEmpty && reminderItems.isEmpty {
                emptyAgenda
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        if !eventItems.isEmpty {
                            sectionHeader("Events", count: eventItems.count)
                            ForEach(eventItems) { event in
                                eventRow(event)
                            }
                        }
                        if !reminderItems.isEmpty {
                            sectionHeader("Reminders", count: reminderItems.count)
                                .padding(.top, eventItems.isEmpty ? 0 : 4)
                            ForEach(reminderItems) { event in
                                eventRow(event)
                            }
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.4))
            Text("\(count)")
                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                .foregroundStyle(accent.opacity(0.8))
            Spacer(minLength: 0)
        }
    }

    private var emptyAgenda: some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(accent.opacity(0.8))
            VStack(alignment: .leading, spacing: 2) {
                Text("Nothing scheduled")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                Text("Enjoy the open day.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }

    private func eventRow(_ event: EventModel) -> some View {
        HStack(alignment: .top, spacing: 9) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color(event.calendar.color))
                .frame(width: 3)

            // Tapping the content opens the item in Calendar / Reminders.
            Button {
                openItem(event)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(isCompletedReminder(event) ? .white.opacity(0.4) : .white)
                        .strikethrough(isCompletedReminder(event), color: .white.opacity(0.4))
                        .lineLimit(1)

                    Text(eventTimeLabel(event))
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .monospacedDigit()

                    if let location = event.location, !location.isEmpty {
                        Label(location, systemImage: "mappin")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                            .labelStyle(.titleAndIcon)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(event.type.isReminder ? "Open in Reminders" : "Open in Calendar")

            if case .reminder(let completed) = event.type {
                Button {
                    Task { await model.setReminderCompleted(event: event, completed: !completed) }
                } label: {
                    Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(completed ? accent : .white.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    /// Opens the event in Calendar.app or the reminder in Reminders.app using
    /// the item's native URL scheme.
    private func openItem(_ event: EventModel) {
        guard let url = event.calendarAppURL() else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Grouping

    private var eventItems: [EventModel] {
        model.events.filter {
            if case .reminder = $0.type { return false }
            return true
        }
    }

    private var reminderItems: [EventModel] {
        model.events.filter {
            if case .reminder = $0.type { return true }
            return false
        }
    }

    // MARK: - Date helpers

    /// Weekday header symbols (S M T W T F S), locale-aware.
    private var weekdaySymbols: [String] {
        let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols
        let first = Calendar.current.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    /// The displayed month, laid out as 6 weeks of 7 days (nil = padding day
    /// outside range). Includes leading/trailing days from adjacent months.
    private var monthWeeks: [[Date?]] {
        let calendar = Calendar.current
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: model.selectedDate),
            let firstWeek = calendar.dateInterval(of: .weekOfYear, for: monthInterval.start)
        else { return [] }

        var days: [Date?] = []
        var cursor = firstWeek.start
        for _ in 0..<42 {   // 6 weeks × 7
            days.append(cursor)
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor
        }
        return stride(from: 0, to: 42, by: 7).map { Array(days[$0..<$0 + 7]) }
    }

    private func isInDisplayedMonth(_ day: Date) -> Bool {
        Calendar.current.isDate(day, equalTo: model.selectedDate, toGranularity: .month)
    }

    private func shiftMonth(by months: Int) {
        guard let target = Calendar.current.date(byAdding: .month, value: months, to: model.selectedDate) else { return }
        Task { await model.selectDate(target) }
    }

    private var monthTitle: String {
        model.selectedDate.formatted(.dateTime.month(.wide))
    }

    private var yearTitle: String {
        model.selectedDate.formatted(.dateTime.year())
    }

    private var selectedDayTitle: String {
        if isSameDay(model.selectedDate, Date()) {
            return "Today"
        }
        return model.selectedDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private func isSameDay(_ a: Date, _ b: Date) -> Bool {
        Calendar.current.isDate(a, inSameDayAs: b)
    }

    private func isCompletedReminder(_ event: EventModel) -> Bool {
        if case .reminder(let completed) = event.type { return completed }
        return false
    }

    private func eventTimeLabel(_ event: EventModel) -> String {
        if event.isAllDay { return "All day" }
        let start = event.start.formatted(date: .omitted, time: .shortened)
        let end = event.end.formatted(date: .omitted, time: .shortened)
        return "\(start) – \(end)"
    }
}

#Preview("Calendar Widget Page") {
    let model = CalendarWidgetModel(widgetID: "calendar-preview")

    return CalendarWidgetPageView(
        widget: try! Widget(
            manifest: WidgetManifest(
                schema: 1,
                kind: .interactive,
                id: "calendar",
                name: "Calendar",
                author: "Preview",
                source: nil,
                extract: nil,
                render: .init(
                    template: .iconLabel,
                    slots: [
                        "icon": .string("calendar"),
                        "label": .string("Full calendar"),
                        "color": .string("accent"),
                    ]
                ),
                onTap: nil,
                permissions: nil,
                interactive: .init(type: .calendar)
            ),
            interactiveRuntime: model,
            status: .ok
        ),
        model: model
    )
    .frame(width: 500, height: 210)
    .background(.black)
}
