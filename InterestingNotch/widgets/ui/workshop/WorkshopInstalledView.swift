//
//  WorkshopInstalledView.swift
//  InterestingNotch
//
//  Created by Codex on 2026-07-13.
//

import Defaults
import KeyboardShortcuts
import SwiftUI

struct WorkshopInstalledView: View {
    @ObservedObject private var engine = WidgetEngine.shared
    @Default(.pinnedWidgetIDs) private var pinnedWidgetIDs

    private var pinnedWidgets: [Widget] {
        pinnedWidgetIDs.compactMap { id in
            engine.widgets.first(where: { $0.id == id })
        }
    }

    var body: some View {
        Form {
            if pinnedWidgets.isEmpty {
                Section {
                    Text("No widgets are pinned right now.")
                        .foregroundStyle(.secondary)
                } footer: {
                    Text("Pin a widget from Browse to make it appear in the notch and configure it here.")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            } else {
                ForEach(pinnedWidgets, id: \.id) { widget in
                    WorkshopInstalledSettingsRegistry.settingsSection(
                        for: widget,
                        pinnedWidgetIDs: $pinnedWidgetIDs
                    )
                }
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Installed")
    }
}

enum WorkshopInstalledSettingsRegistry {
    @ViewBuilder
    static func settingsSection(
        for widget: Widget,
        pinnedWidgetIDs: Binding<[String]>
    ) -> some View {
        switch widget.id {
        case "color-picker":
            ColorPickerInstalledSettingsSection(widget: widget, pinnedWidgetIDs: pinnedWidgetIDs)
        case "clipboard-history":
            ClipboardHistoryInstalledSettingsSection(widget: widget, pinnedWidgetIDs: pinnedWidgetIDs)
        default:
            GenericInstalledSettingsSection(widget: widget, pinnedWidgetIDs: pinnedWidgetIDs)
        }
    }
}

private struct ColorPickerInstalledSettingsSection: View {
    let widget: Widget
    @Binding var pinnedWidgetIDs: [String]

    var body: some View {
        Section {
            LabeledContent("Pick color shortcut") {
                KeyboardShortcuts.Recorder(for: .colorPickerPickColor)
                    .frame(minWidth: 130)
            }

            Button("Unpin", role: .destructive) {
                pinnedWidgetIDs = WidgetPinStore.unpin(widget.id, in: pinnedWidgetIDs)
            }
        } header: {
            Text(widget.manifest.name)
        } footer: {
            Text("Use the shortcut to open the system eyedropper and store the picked color in this widget’s recent history.")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
    }
}

private struct ClipboardHistoryInstalledSettingsSection: View {
    @ObservedObject private var engine = WidgetEngine.shared
    let widget: Widget
    @Binding var pinnedWidgetIDs: [String]
    @Default(.clipboardHistoryMaxItems) private var maxHistoryItems

    var body: some View {
        Section {
            LabeledContent("Open clipboard shortcut") {
                KeyboardShortcuts.Recorder(for: .clipboardHistoryPanel)
                    .frame(minWidth: 130)
            }

            Stepper(value: $maxHistoryItems, in: 1...ClipboardHistoryStore.maximumLimit) {
                LabeledContent("Max history items") {
                    Text("\(maxHistoryItems)")
                        .monospacedDigit()
                }
            }

            Button("Clear saved history", role: .destructive) {
                if let model = engine.widgets.first(where: { $0.id == widget.id })?.interactiveRuntime as? ClipboardHistoryWidgetModel {
                    model.clearHistory()
                }
                Defaults[.clipboardHistoryStoreData] = nil
            }

            Button("Unpin", role: .destructive) {
                pinnedWidgetIDs = WidgetPinStore.unpin(widget.id, in: pinnedWidgetIDs)
            }
        } header: {
            Text(widget.manifest.name)
        } footer: {
            Text("Use the shortcut to jump straight to the clipboard widget. Pinned clips stay in history until you clear or unpin them. Max history is capped at 100 items.")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
        .onChange(of: maxHistoryItems) { _, newValue in
            maxHistoryItems = min(max(newValue, 1), ClipboardHistoryStore.maximumLimit)
            trimClipboardHistoryStore()
        }
    }

    private func trimClipboardHistoryStore() {
        guard
            let data = Defaults[.clipboardHistoryStoreData],
            let payload = try? JSONDecoder().decode([String: [ClipboardHistoryItem]].self, from: data)
        else {
            return
        }

        let trimmedPayload = payload.mapValues { items in
            ClipboardHistoryStore.enforcingLimit(on: items, limit: maxHistoryItems)
        }

        Defaults[.clipboardHistoryStoreData] = try? JSONEncoder().encode(trimmedPayload)
    }
}

private struct GenericInstalledSettingsSection: View {
    let widget: Widget
    @Binding var pinnedWidgetIDs: [String]

    var body: some View {
        Section {
            Text("This widget does not expose installed options yet.")
                .foregroundStyle(.secondary)

            Button("Unpin", role: .destructive) {
                pinnedWidgetIDs = WidgetPinStore.unpin(widget.id, in: pinnedWidgetIDs)
            }
        } header: {
            Text(widget.manifest.name)
        } footer: {
            Text("Widget-specific settings will appear here as more widgets declare them.")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
    }
}

#Preview("Workshop Installed") {
    WorkshopInstalledPreviewHost()
        .frame(width: 760, height: 520)
}

private struct WorkshopInstalledPreviewHost: View {
    @State private var loaded = false

    var body: some View {
        WorkshopInstalledView()
            .task {
                guard !loaded else { return }
                loaded = true
                Defaults[.pinnedWidgetIDs] = ["color-picker", "system-monitor"]
                WidgetEngine.shared.load(makePreviewWidgets())
            }
    }

    @MainActor
    private func makePreviewWidgets() -> [Widget] {
        [
            makeInteractivePreviewWidget(),
            makeSystemMonitorPreviewWidget(),
        ]
        .compactMap { $0 }
    }

    @MainActor
    private func makeInteractivePreviewWidget() -> Widget? {
        try? Widget(
            manifest: WidgetManifest(
                schema: 1,
                kind: .interactive,
                id: "color-picker",
                name: "Color Picker",
                author: "Preview",
                source: nil,
                extract: nil,
                render: .init(
                    template: .iconLabel,
                    slots: [
                        "icon": .string("eyedropper"),
                        "label": .string("Pick color"),
                        "color": .string("accent"),
                    ]
                ),
                onTap: nil,
                permissions: nil,
                interactive: .init(type: .colorPicker)
            ),
            lastValue: nil,
            status: .ok
        )
    }

    @MainActor
    private func makeSystemMonitorPreviewWidget() -> Widget? {
        try? Widget(
            manifest: WidgetManifest(
                schema: 1,
                kind: .data,
                id: "system-monitor",
                name: "System Monitor",
                author: "Preview",
                source: .init(
                    type: .framework,
                    run: nil,
                    url: nil,
                    method: nil,
                    headers: nil,
                    api: "system-monitor",
                    interval: 3,
                    timeout: nil,
                    cwd: nil,
                    env: nil
                ),
                extract: .init(method: .jsonPath, pattern: nil, path: "$", table: nil),
                render: .init(
                    template: .text,
                    slots: [
                        "icon": .string("cpu"),
                        "label": .string("System Monitor"),
                        "color": .string("accent"),
                    ]
                ),
                onTap: nil,
                permissions: nil,
                interactive: nil
            ),
            lastValue: SystemMonitorSnapshot(
                cpuPercent: 27,
                memoryPercent: 61,
                diskPercent: 73,
                uptimeText: "5h 42m",
                loadAverageText: "1.12 1.08 0.98"
            ).widgetValue,
            status: .ok
        )
    }
}
