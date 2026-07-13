//
//  ClipboardHistoryWidgetPageView.swift
//  boringNotch
//
//  Created by Codex on 2026-07-13.
//

import SwiftUI

struct ClipboardHistoryWidgetPageView: View {
    let widget: Widget

    @ObservedObject var model: ClipboardHistoryWidgetModel
    @State private var hoveredItemID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()
                .overlay(Color.white.opacity(0.10))
                .padding(.top, 10)
                .padding(.bottom, 12)

            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(widget.manifest.name)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)

                Text("Recent clips stay ready to copy again.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button("Clear") {
                model.clearHistory()
            }
            .buttonStyle(.plain)
            .font(.caption.weight(.semibold))
            .foregroundStyle(model.items.isEmpty ? Color.secondary.opacity(0.45) : Color.white.opacity(0.75))
            .disabled(model.items.isEmpty)
        }
        .padding(.top, 10)
        .padding(.leading, 5)
    }

    @ViewBuilder
    private var content: some View {
        if model.items.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Copy something to start a history.")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                Text("Text, links, and images appear here. Concealed clipboard items are skipped automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(model.items) { item in
                        historyCard(for: item)
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private func historyCard(for item: ClipboardHistoryItem) -> some View {
        Button {
            model.restoreHistoryItem(item)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    Label(item.kind.title, systemImage: item.kind.symbolName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .labelStyle(.titleAndIcon)

                    Spacer(minLength: 0)

                    pinButton(for: item)
                        .opacity(hoveredItemID == item.id || item.pinned ? 1 : 0)
                }

                preview(for: item)

                Spacer(minLength: 0)

                Text(item.previewSubtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(12)
            .frame(width: 168, height: 116, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(nsColor: .secondarySystemFill).opacity(0.45))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(hoveredItemID == item.id ? 0.12 : 0.06), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovering in
            hoveredItemID = isHovering ? item.id : (hoveredItemID == item.id ? nil : hoveredItemID)
        }
    }

    @ViewBuilder
    private func preview(for item: ClipboardHistoryItem) -> some View {
        switch item.kind {
        case .text:
            Text(item.previewTitle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .link:
            Text(item.previewTitle)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .image:
            if let image = item.thumbnailImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 54, alignment: .leading)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 54)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }
        }
    }

    private func pinButton(for item: ClipboardHistoryItem) -> some View {
        Button {
            model.togglePin(for: item.id)
        } label: {
            Image(systemName: item.pinned ? "pin.fill" : "pin")
                .font(.caption.weight(.semibold))
                .foregroundStyle(item.pinned ? .white : .secondary)
        }
        .buttonStyle(.plain)
        .help(item.pinned ? "Unpin item" : "Keep item")
    }
}

#Preview("Clipboard History Widget") {
    ClipboardHistoryWidgetPreview()
        .frame(width: 440, height: 180)
        .background(.black)
}

private struct ClipboardHistoryWidgetPreview: View {
    @MainActor
    private let model = ClipboardHistoryWidgetModel(
        widgetID: "clipboard-preview",
        items: [
            ClipboardHistoryItem(
                kind: .text,
                content: "Design tokens for the new notch spacing pass.",
                fingerprint: "text-preview"
            ),
            ClipboardHistoryItem(
                kind: .link,
                content: "https://github.com/nodescraper/boringnotch-se",
                fingerprint: "link-preview",
                pinned: true
            ),
        ]
    )

    var body: some View {
        if let widget = previewWidget {
            ClipboardHistoryWidgetPageView(widget: widget, model: model)
        }
    }

    @MainActor
    private var previewWidget: Widget? {
        try? Widget(
            manifest: WidgetManifest(
                schema: 1,
                kind: .interactive,
                id: "clipboard-history",
                name: "Clipboard History",
                author: "Preview",
                source: nil,
                extract: nil,
                render: .init(
                    template: .iconLabel,
                    slots: [
                        "icon": .string("document.on.clipboard"),
                        "label": .string("Recent clips"),
                        "color": .string("accent"),
                    ]
                ),
                onTap: nil,
                permissions: ["clipboard"],
                interactive: .init(type: .clipboardHistory)
            ),
            interactiveRuntime: model,
            status: .ok
        )
    }
}
