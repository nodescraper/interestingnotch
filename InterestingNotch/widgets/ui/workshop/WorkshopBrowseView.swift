//
//  WorkshopBrowseView.swift
//  InterestingNotch
//
//  Created by Codex on 2026-07-13.
//

import Defaults
import SwiftUI

private enum WorkshopBrowseFilter: String, CaseIterable, Identifiable {
    case all
    case tab
    case peek

    var id: Self { self }

    var title: String {
        switch self {
        case .all: "All"
        case .tab: "Tab"
        case .peek: "Peek"
        }
    }
}

struct WorkshopBrowseView: View {
    @ObservedObject private var engine = WidgetEngine.shared
    @Default(.pinnedWidgetIDs) private var pinnedWidgetIDs
    @State private var searchText = ""
    @State private var selectedFilter: WorkshopBrowseFilter = .all

    private var filteredWidgets: [Widget] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return engine.widgets.filter { widget in
            let matchesFilter: Bool = switch selectedFilter {
            case .all:
                true
            case .tab:
                widget.manifest.presentation.supportsTab
            case .peek:
                widget.manifest.presentation.supportsPeek
            }

            let matchesSearch = query.isEmpty ||
                widget.manifest.name.localizedCaseInsensitiveContains(query) ||
                (widget.manifest.author?.localizedCaseInsensitiveContains(query) == true) ||
                WorkshopWidgetCatalog.description(for: widget).localizedCaseInsensitiveContains(query)

            return matchesFilter && matchesSearch
        }
    }

    var body: some View {
        Form {
            Section {
                Picker("Show", selection: $selectedFilter) {
                    ForEach(WorkshopBrowseFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Widget Store")
            } footer: {
                Text("Choose where a widget can appear. Tab widgets use a notch icon; Peek widgets stay compact and do not use a tab slot.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
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
                Text("Browse widgets installed from Application Support. Tab-compatible widgets can be pinned; peek widgets stay available without taking a tab slot.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Browse")
        .searchable(text: $searchText, prompt: "Widgets")
    }

    private func availableWidgetRow(for widget: Widget) -> some View {
        HStack(alignment: .top, spacing: 12) {
            widgetIcon(for: widget)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(widget.manifest.name)
                        .font(.headline)
                    presentationBadges(for: widget)
                }

                Text(WorkshopWidgetCatalog.description(for: widget))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            if widget.manifest.presentation.supportsTab {
                Button(isPinned(widget) ? "Unpin" : "Pin") {
                    pinnedWidgetIDs = WidgetPinStore.toggle(widget.id, in: pinnedWidgetIDs)
                }
            } else {
                Text("Peek only")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

    @ViewBuilder
    private func presentationBadges(for widget: Widget) -> some View {
        if widget.manifest.presentation.supportsTab {
            Text("Tab")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.15), in: Capsule())
        }
        if widget.manifest.presentation.supportsPeek {
            Text("Peek")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.15), in: Capsule())
        }
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
        case "clipboard-history":
            return "Keep recent text, links, and images nearby, and recopy any clip with one click."
        case "voice-recorder":
            return "Record quick voice notes from the notch, track elapsed time live, and reveal the saved file right away."
        case "system-monitor":
            return "Watch live CPU and memory usage in the notch, with a compact closed-notch split view."
        default:
            return widget.manifest.presentation == .peek
                ? "A compact peek-only widget that does not add a tab to the notch."
                : "Pin this widget to add it as a tab in the notch."
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
