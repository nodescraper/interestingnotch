//
//  WorkshopBrowseView.swift
//  boringNotch
//
//  Created by Codex on 2026-07-13.
//

import Defaults
import SwiftUI

struct WorkshopBrowseView: View {
    @ObservedObject private var engine = WidgetEngine.shared
    @Default(.pinnedWidgetIDs) private var pinnedWidgetIDs

    var body: some View {
        Form {
            Section {
                if engine.widgets.isEmpty {
                    Text("No widgets installed yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(engine.widgets, id: \.id) { widget in
                        availableWidgetRow(for: widget)
                    }
                }
            } header: {
                Text("Available Widgets")
            } footer: {
                Text("Available widgets are loaded from Application Support. Pin one here to make it appear as a notch tab.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Browse")
    }

    private func availableWidgetRow(for widget: Widget) -> some View {
        HStack(alignment: .top, spacing: 12) {
            widgetIcon(for: widget)

            VStack(alignment: .leading, spacing: 3) {
                Text(widget.manifest.name)
                    .font(.headline)

                Text(WorkshopWidgetCatalog.description(for: widget))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            Button(isPinned(widget) ? "Unpin" : "Pin") {
                pinnedWidgetIDs = WidgetPinStore.toggle(widget.id, in: pinnedWidgetIDs)
            }
        }
        .padding(.vertical, 4)
    }

    private func widgetIcon(for widget: Widget) -> some View {
        let symbol = WidgetSlotRenderer.resolvedString(
            forSlotNamed: "icon",
            in: widget.manifest.render.slots,
            value: widget.lastValue,
            fallback: "square.grid.2x2"
        )

        return Image(systemName: symbol)
            .frame(width: 18, height: 18)
            .foregroundStyle(widget.resolvedColor)
    }

    private func isPinned(_ widget: Widget) -> Bool {
        WidgetPinStore.isPinned(widget.id, in: pinnedWidgetIDs)
    }
}

enum WorkshopWidgetCatalog {
    static func description(for widget: Widget) -> String {
        switch widget.id {
        case "color-picker":
            return "Pick colors anywhere on screen, copy values, and keep a quick recent history."
        case "timer":
            return "Run a focused countdown with presets in the notch and keep a live closed-notch glance."
        case "clipboard-history":
            return "Keep recent text, links, and images nearby, and recopy any clip with one click."
        case "system-monitor":
            return "Watch live CPU and memory usage in the notch, with a compact closed-notch split view."
        default:
            return "Pin this widget to add it as a tab in the notch."
        }
    }
}

#Preview("Workshop Browse") {
    WorkshopBrowsePreviewHost()
        .frame(width: 760, height: 520)
}

private struct WorkshopBrowsePreviewHost: View {
    @State private var loaded = false

    var body: some View {
        WorkshopBrowseView()
            .task {
                guard !loaded else { return }
                loaded = true
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
