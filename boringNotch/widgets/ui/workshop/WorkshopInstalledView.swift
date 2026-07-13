//
//  WorkshopInstalledView.swift
//  boringNotch
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
            KeyboardShortcuts.Recorder("Pick color:", name: .colorPickerPickColor)

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
                Defaults[.pinnedWidgetIDs] = ["color-picker"]
                WidgetEngine.shared.load(makePreviewWidgets())
            }
    }

    @MainActor
    private func makePreviewWidgets() -> [Widget] {
        [
            makeInteractivePreviewWidget(),
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
}
