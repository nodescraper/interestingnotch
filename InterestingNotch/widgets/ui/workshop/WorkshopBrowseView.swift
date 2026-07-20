//
//  WorkshopBrowseView.swift
//  InterestingNotch
//
//  Created by Codex on 2026-07-13.
//

import Defaults
import SwiftUI

struct WorkshopBrowseView: View {
    @ObservedObject private var engine = WidgetEngine.shared
    @Default(.pinnedWidgetIDs) private var pinnedWidgetIDs
    @State private var searchText = ""
    let openPinnedWidget: (String) -> Void

    init(openPinnedWidget: @escaping (String) -> Void = { _ in }) {
        self.openPinnedWidget = openPinnedWidget
    }

    private var filteredWidgets: [Widget] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return engine.widgets.filter { widget in
            let matchesSearch = query.isEmpty ||
                widget.manifest.name.localizedCaseInsensitiveContains(query) ||
                (widget.manifest.author?.localizedCaseInsensitiveContains(query) == true) ||
                WorkshopWidgetCatalog.description(for: widget).localizedCaseInsensitiveContains(query)

            return matchesSearch
        }
    }

    private var pinnedWidgets: [Widget] {
        pinnedWidgetIDs.compactMap { id in
            engine.widgets.first(where: { $0.id == id })
        }
    }

    private var filteredPinnedWidgets: [Widget] {
        let availableIDs = Set(filteredWidgets.map(\.id))
        return pinnedWidgets.filter { availableIDs.contains($0.id) || searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
        Form {
            if !filteredPinnedWidgets.isEmpty {
                Section {
                    ForEach(filteredPinnedWidgets, id: \.id) { widget in
                        pinnedWidgetRow(for: widget)
                    }
                } header: {
                    HStack {
                        Text("Pinned Widgets")
                        Spacer()
                        Text("\(filteredPinnedWidgets.count)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                } footer: {
                    Text("Pinned widgets appear as tabs in the notch. Open one here to manage its own settings page.")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }

            Section {
                if filteredWidgets.isEmpty {
                    Text(searchText.isEmpty ? "No widgets match this filter." : "No widgets match your search.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredWidgets, id: \.id) { widget in
                        availableWidgetRow(for: widget)
                    }
                }
            } header: {
                HStack {
                    Text("Available Widgets")
                    Spacer()
                    Text("\(filteredWidgets.count)")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            } footer: {
                Text("Browse widgets installed from Application Support. Pin a widget to add it as a notch tab.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Widgets")
        .searchable(text: $searchText, prompt: "Widgets")
    }

    private func pinnedWidgetRow(for widget: Widget) -> some View {
        Button {
            openPinnedWidget(widget.id)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                widgetIcon(for: widget)

                VStack(alignment: .leading, spacing: 3) {
                    Text(widget.manifest.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(WorkshopWidgetCatalog.description(for: widget))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 12)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Color(nsColor: .controlBackgroundColor))
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
        case "calendar":
            return "Pin the full calendar as its own notch tab while keeping the compact inline calendar separate."
        case "color-picker":
            return "Pick colors anywhere on screen, copy values, and keep a quick recent history."
        case "timer":
            return "Run a focused countdown with presets in the notch and keep a live closed-notch glance."
        case "sports":
            return "Follow teams across leagues, surface the highest-priority live game in the closed notch, and open a full multi-game tab."
        case "clipboard-history":
            return "Keep recent text, links, and images nearby, and recopy any clip with one click."
        case "voice-recorder":
            return "Record quick voice notes from the notch, track elapsed time live, and reveal the saved file right away."
        case "system-monitor":
            return "Watch live CPU and memory usage in the full System Monitor tab."
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
