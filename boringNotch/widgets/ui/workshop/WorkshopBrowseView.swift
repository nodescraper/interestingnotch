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
        WidgetGridView(
            widgets: engine.widgets,
            emptyIcon: "square.grid.2x2",
            emptyTitle: "No widgets yet",
            emptyMessage: "Add .notchwidget.json files to Application Support to browse and pin them here."
        ) { widget in
            WidgetCardView(widget: widget) {
                pinButton(for: widget)
            }
        }
        .navigationTitle("Browse")
    }

    private func pinButton(for widget: Widget) -> some View {
        let isPinned = WidgetPinStore.isPinned(widget.id, in: pinnedWidgetIDs)

        return Button {
            pinnedWidgetIDs = WidgetPinStore.toggle(widget.id, in: pinnedWidgetIDs)
        } label: {
            Label(isPinned ? "Unpin" : "Pin", systemImage: isPinned ? "pin.fill" : "pin")
                .labelStyle(.iconOnly)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(isPinned ? widget.resolvedColor : .white.opacity(0.9))
                .padding(8)
                .background(
                    Capsule(style: .continuous)
                        .fill(.black.opacity(0.35))
                )
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .help(isPinned ? "Unpin from notch tabs" : "Pin to notch tabs")
        .accessibilityLabel(isPinned ? "Unpin \(widget.manifest.name)" : "Pin \(widget.manifest.name)")
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
            makePreviewWidget(
                id: "preview-git",
                name: "Git Status",
                template: .iconLabel,
                lastValue: .integer(2),
                status: .ok,
                color: "accent",
                icon: "arrow.triangle.branch",
                label: "$value changed"
            ),
            makePreviewWidget(
                id: "preview-brew",
                name: "Brew Updates",
                template: .iconLabel,
                lastValue: nil,
                status: .loading,
                color: "warn",
                icon: "shippingbox",
                label: "Checking updates"
            ),
        ]
        .compactMap { $0 }
    }

    @MainActor
    private func makePreviewWidget(
        id: String,
        name: String,
        template: WidgetManifest.Render.Template,
        lastValue: WidgetValue?,
        status: WidgetStatus,
        color: String,
        icon: String,
        label: String
    ) -> Widget? {
        try? Widget(
            manifest: WidgetManifest(
                schema: 1,
                kind: .data,
                id: id,
                name: name,
                author: "Preview",
                source: .init(
                    type: .command,
                    run: "cat /dev/null",
                    url: nil,
                    method: nil,
                    headers: nil,
                    api: nil,
                    interval: 10,
                    timeout: 1,
                    cwd: nil,
                    env: nil
                ),
                extract: .init(
                    method: .raw,
                    pattern: nil,
                    path: nil,
                    table: nil
                ),
                render: .init(
                    template: template,
                    slots: [
                        "icon": .string(icon),
                        "label": .string(label),
                        "color": .string(color),
                    ]
                ),
                onTap: nil,
                permissions: nil
            ),
            executor: WorkshopBrowsePreviewExecutor(),
            extractor: ExtractorPipeline(extractors: [RawExtractor()]),
            lastValue: lastValue,
            status: status
        )
    }
}

private actor WorkshopBrowsePreviewExecutor: ChannelExecutor {
    let channelType: WidgetManifest.Source.ChannelType = .command

    func run(source: WidgetManifest.Source) async throws -> String {
        ""
    }
}
