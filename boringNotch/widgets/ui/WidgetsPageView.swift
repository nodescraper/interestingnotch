//
//  WidgetsPageView.swift
//  boringNotch
//
//  Created by Codex on 2026-07-13.
//

import SwiftUI

struct WidgetsPageView: View {
    @ObservedObject private var engine = WidgetEngine.shared

    var body: some View {
        WidgetGridView(
            widgets: engine.widgets,
            emptyIcon: "square.grid.2x2",
            emptyTitle: "No widgets yet",
            emptyMessage: "Install a widget in Workshop to see live cards here."
        ) { widget in
            WidgetCardView(widget: widget)
        }
    }
}

#Preview("Widgets Empty") {
    WidgetsPageView()
        .frame(width: 500, height: 320)
        .background(.black)
}

#Preview("Widgets Loaded") {
    WidgetsPageLoadedPreview()
        .frame(width: 500, height: 320)
        .background(.black)
}

private struct WidgetsPageLoadedPreview: View {
    @State private var didLoadPreview = false

    var body: some View {
        WidgetsPageView()
            .task {
                guard !didLoadPreview else { return }
                didLoadPreview = true
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
                label: "$value pending"
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
            makePreviewWidget(
                id: "preview-usage",
                name: "Codex Usage",
                template: .progress,
                lastValue: .double(41.2),
                status: .error("CLI not reachable"),
                color: "good",
                icon: "gauge.with.needle",
                label: "$value%"
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
                permissions: nil,
                interactive: nil
            ),
            executor: WidgetsPagePreviewExecutor(),
            extractor: ExtractorPipeline(extractors: [RawExtractor()]),
            lastValue: lastValue,
            status: status
        )
    }
}

private actor WidgetsPagePreviewExecutor: ChannelExecutor {
    let channelType: WidgetManifest.Source.ChannelType = .command

    func run(source: WidgetManifest.Source) async throws -> String {
        ""
    }
}
