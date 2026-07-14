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
    private let cardSize: CGFloat = 100

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
            .padding(.top, 10)
            .padding(.leading, 5)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(model.items) { item in
                        historyCard(for: item)
                    }
                }
            }
            .padding(.top, 10)
            .padding(.leading, 15)
            .padding(.bottom, 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private func historyCard(for item: ClipboardHistoryItem) -> some View {
        Button {
            model.restoreHistoryItem(item)
        } label: {
            ZStack(alignment: .topLeading) {
                cardBackground(for: item)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        Label(item.kind.title, systemImage: item.kind.symbolName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(item.kind == .image ? .white.opacity(0.9) : .secondary)
                            .labelStyle(.titleAndIcon)

                        Spacer(minLength: 0)

                        pinButton(for: item)
                            .opacity(hoveredItemID == item.id || item.pinned ? 1 : 0)
                    }

                    preview(for: item)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
            }
            .frame(width: cardSize, height: cardSize, alignment: .leading)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(hoveredItemID == item.id ? 0.12 : 0.06), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovering in
            hoveredItemID = isHovering ? item.id : (hoveredItemID == item.id ? nil : hoveredItemID)
        }
    }

    @ViewBuilder
    private func cardBackground(for item: ClipboardHistoryItem) -> some View {
        switch item.kind {
        case .image:
            if let image = item.thumbnailImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay {
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.18),
                                Color.black.opacity(0.48),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(nsColor: .secondarySystemFill).opacity(0.45))
            }
        case .text, .link:
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .secondarySystemFill).opacity(0.45))
        }
    }

    @ViewBuilder
    private func preview(for item: ClipboardHistoryItem) -> some View {
        switch item.kind {
        case .text:
            Text(item.previewTitle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .lineLimit(2)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .link:
            Text(item.previewTitle)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(2)
                .truncationMode(.middle)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .image:
            Text("Tap to copy image")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.95))
                .frame(maxWidth: .infinity, alignment: .leading)
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
