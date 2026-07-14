//
//  CalendarWidgetModel.swift
//  boringNotch
//
//  Created by Codex on 2026-07-14.
//

import Combine
import EventKit
import Foundation

@MainActor
final class CalendarWidgetModel: ObservableObject, InteractiveWidgetRuntime {
    let interactiveKind: WidgetManifest.Interactive.Kind = .calendar
    let widgetID: String

    @Published private(set) var selectedDate: Date
    @Published private(set) var events: [EventModel] = []
    @Published private(set) var eventCalendars: [CalendarModel] = []
    @Published private(set) var reminderLists: [CalendarModel] = []
    @Published private(set) var selectedCalendarIDs: Set<String> = []
    @Published private(set) var calendarAuthorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published private(set) var reminderAuthorizationStatus: EKAuthorizationStatus = .notDetermined

    private let calendarManager: CalendarManager
    private var cancellables: Set<AnyCancellable> = []

    init(
        widgetID: String,
        calendarManager: CalendarManager = .shared
    ) {
        self.widgetID = widgetID
        self.calendarManager = calendarManager
        self.selectedDate = calendarManager.currentWeekStartDate

        bindManager()

        Task {
            await refresh()
        }
    }

    var selectedCalendars: [CalendarModel] {
        let selectedIDs = selectedCalendarIDs
        return (eventCalendars + reminderLists).filter { selectedIDs.contains($0.id) }
    }

    func refresh() async {
        await calendarManager.checkCalendarAuthorization()
        await calendarManager.checkReminderAuthorization()
        await calendarManager.updateCurrentDate(selectedDate)
    }

    func selectDate(_ date: Date) async {
        selectedDate = Calendar.current.startOfDay(for: date)
        await calendarManager.updateCurrentDate(selectedDate)
    }

    func setReminderCompleted(event: EventModel, completed: Bool) async {
        guard case .reminder = event.type else { return }
        await calendarManager.setReminderCompleted(reminderID: event.id, completed: completed)
    }

    private func bindManager() {
        calendarManager.$currentWeekStartDate
            .sink { [weak self] in self?.selectedDate = $0 }
            .store(in: &cancellables)

        calendarManager.$events
            .sink { [weak self] in self?.events = $0 }
            .store(in: &cancellables)

        calendarManager.$eventCalendars
            .sink { [weak self] in self?.eventCalendars = $0 }
            .store(in: &cancellables)

        calendarManager.$reminderLists
            .sink { [weak self] in self?.reminderLists = $0 }
            .store(in: &cancellables)

        calendarManager.$selectedCalendarIDs
            .sink { [weak self] in self?.selectedCalendarIDs = $0 }
            .store(in: &cancellables)

        calendarManager.$calendarAuthorizationStatus
            .sink { [weak self] in self?.calendarAuthorizationStatus = $0 }
            .store(in: &cancellables)

        calendarManager.$reminderAuthorizationStatus
            .sink { [weak self] in self?.reminderAuthorizationStatus = $0 }
            .store(in: &cancellables)
    }
}
