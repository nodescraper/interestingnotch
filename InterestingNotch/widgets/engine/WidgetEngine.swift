//
//  WidgetEngine.swift
//  InterestingNotch
//
//  Created by Codex on 2026-07-13.
//

import Foundation

@MainActor
final class WidgetEngine: ObservableObject {
    static let shared = WidgetEngine()

    @Published private(set) var widgets: [Widget] = []

    private var tasks: [String: Task<Void, Never>] = [:]

    init() {}

    deinit {
        tasks.values.forEach { $0.cancel() }
    }

    func load(_ widgets: [Widget]) {
        cancelAllTasks()
        self.widgets = widgets

        for widget in widgets where widget.status != .disabled && widget.isPollingEnabled {
            tasks[widget.id] = makePollingTask(for: widget)
        }
    }

    private func cancelAllTasks() {
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
    }

    private func makePollingTask(for widget: Widget) -> Task<Void, Never> {
        Task { [weak self] in
            while !Task.isCancelled {
                await self?.tick(widgetID: widget.id)

                guard !Task.isCancelled else { return }

                let interval = self?.interval(for: widget.id) ?? widget.interval
                let sleepDuration = UInt64(max(interval, 0) * 1_000_000_000)

                if sleepDuration == 0 {
                    await Task.yield()
                } else {
                    try? await Task.sleep(nanoseconds: sleepDuration)
                }
            }
        }
    }

    private func interval(for widgetID: String) -> TimeInterval? {
        widgets.first(where: { $0.id == widgetID })?.interval
    }

    private func tick(widgetID: String) async {
        guard let widget = widgets.first(where: { $0.id == widgetID }) else {
            tasks[widgetID]?.cancel()
            tasks[widgetID] = nil
            return
        }

        guard
            let source = widget.manifest.source,
            let executor = widget.executor,
            let extractor = widget.extractor
        else {
            widget.status = .error("Widget poll configuration is unavailable.")
            return
        }

        do {
            let rawOutput = try await executor.run(source: source)
            let value = try extractor.extract(from: rawOutput)
            widget.lastValue = value
            widget.status = .ok
        } catch {
            widget.status = .error(error.localizedDescription)
        }
    }
}
