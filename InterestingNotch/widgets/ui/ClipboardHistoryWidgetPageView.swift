//
//  ClipboardHistoryWidgetPageView.swift
//  InterestingNotch
//
//  Created by Codex on 2026-07-13.
//  Redesigned content-forward (Paste / Raycast style): the clip's content is the
//  hero, type is shown by a quiet icon + meaningful metadata — never a "Text" label.
//

import SwiftUI
import AppKit

struct ClipboardHistoryWidgetPageView: View {
    let widget: Widget

    @ObservedObject var model: ClipboardHistoryWidgetModel
    @State private var hoveredItemID: String?

    // Horizontal scroll state (manual, so click-drag works without a trackpad).
    @State private var scrollOffset: CGFloat = 0
    @State private var liveDragOffset: CGFloat?
    @State private var dragStartOffset: CGFloat?

    // Memoized content detection so hover-driven re-renders don't re-parse every
    // card (hex/URL parsing per card per frame was the main cost).
    @State private var detailCache: [String: ClipDetail] = [:]

    private let accent = Color.effectiveAccent
    private let cardSpacing: CGFloat = 10
    // Cards fill the full height of the drop area; width = height × 1.56
    // (was 1.2, bumped 30% wider so the content has room to breathe).
    private let cardAspect: CGFloat = 1.56

    /// Detail for an item, computed once and reused. Keyed by id (content is
    /// immutable per item, so id is a stable key).
    private func detail(for item: ClipboardHistoryItem) -> ClipDetail {
        if let cached = detailCache[item.id] { return cached }
        let computed = ClipDetail(item: item)
        // Mutating @State during body isn't allowed; schedule the write.
        DispatchQueue.main.async {
            detailCache[item.id] = computed
            // Prune entries for items no longer present (bounded memory).
            if detailCache.count > model.items.count {
                let live = Set(model.items.map(\.id))
                detailCache = detailCache.filter { live.contains($0.key) }
            }
        }
        return computed
    }

    var body: some View {
        if model.items.isEmpty {
            emptyState
        } else {
            GeometryReader { geo in
                // Card fills the full height of the drop area; width is 120%
                // of the height (1:1.2 → width = height × 1.2).
                let cardHeight = geo.size.height
                let cardWidth = cardHeight * cardAspect

                let viewportWidth = geo.size.width
                let contentWidth = totalContentWidth(cardWidth: cardWidth)
                // How far the row can scroll (0 when everything fits).
                let maxOffset = max(0, contentWidth - viewportWidth)

                LazyHStack(spacing: cardSpacing) {
                    ForEach(model.items) { item in
                        historyCard(for: item, cardWidth: cardWidth, cardHeight: cardHeight)
                    }
                }
                .frame(height: cardHeight, alignment: .topLeading)
                .offset(x: -currentOffset(maxOffset: maxOffset))
                .frame(width: viewportWidth, height: cardHeight, alignment: .topLeading)
                // Clip a touch wider than the cards so a hovered card's border
                // on the top & bottom edges isn't shaved off by the viewport.
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous).inset(by: -3))
                // Trackpad two-finger scroll / mouse wheel, behind the cards so
                // it catches scroll but never steals clicks from the buttons.
                .background(
                    ScrollCatcher { deltaX, deltaY in
                        let raw = abs(deltaX) > abs(deltaY) ? deltaX : deltaY
                        scrollOffset = min(max(scrollOffset - raw, 0), maxOffset)
                    } onEnded: {}
                )
                // Click-and-drag to scroll. simultaneousGesture (not gesture) so
                // card buttons still receive plain taps; higher threshold so a
                // click isn't mistaken for a drag.
                .simultaneousGesture(
                    DragGesture(minimumDistance: 8)
                        .onChanged { value in
                            if dragStartOffset == nil { dragStartOffset = scrollOffset }
                            let base = dragStartOffset ?? scrollOffset
                            liveDragOffset = min(max(base - value.translation.width, 0), maxOffset)
                        }
                        .onEnded { _ in
                            if let live = liveDragOffset { scrollOffset = live }
                            liveDragOffset = nil
                            dragStartOffset = nil
                        }
                )
            }
            // 10pt breathing room on the sides and bottom (and top) of the
            // scroll area inside the panel.
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    /// Total width of all cards + spacing, for a given card width.
    private func totalContentWidth(cardWidth: CGFloat) -> CGFloat {
        let count = CGFloat(model.items.count)
        guard count > 0 else { return 0 }
        return count * cardWidth + (count - 1) * cardSpacing
    }

    /// Live drag offset takes precedence while dragging; else the settled offset.
    private func currentOffset(maxOffset: CGFloat) -> CGFloat {
        let value = liveDragOffset ?? scrollOffset
        return min(max(value, 0), maxOffset)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(accent)
                .padding(.bottom, 2)

            Text("Nothing copied yet")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Text("Text, links, and images you copy show up here.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    // MARK: - Card

    private func historyCard(for item: ClipboardHistoryItem, cardWidth: CGFloat, cardHeight: CGFloat) -> some View {
        let hovered = hoveredItemID == item.id
        let detail = detail(for: item)

        return ZStack(alignment: .topLeading) {
            // Content is the hero — fills the card top-to-bottom.
            VStack(alignment: .leading, spacing: 0) {
                cardHero(for: item, detail: detail)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                // Compact footer: type icon + meta, quiet and out of the way.
                HStack(spacing: 5) {
                    Image(systemName: detail.symbol)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(accent)
                    Text(detail.meta)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                        .tracking(0.4)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
            }
            .padding(12)

            // Pin overlays the top-right corner. Rendered above the card and
            // given its own tap so it never triggers the card's restore tap.
            pinButton(for: item)
                .opacity(hovered || item.pinned ? 1 : 0)
                .frame(maxWidth: .infinity, alignment: .topTrailing)
                .padding(9)
        }
        .frame(width: cardWidth, height: cardHeight, alignment: .topLeading)
        .background(cardBackground(for: item, detail: detail, hovered: hovered))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        // ONE hover/border layer, inset just inside the clipped bounds so it
        // reads as an even outline on all four sides.
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .inset(by: 0.5)
                .strokeBorder(.white.opacity(hovered ? 0.22 : 0.07), lineWidth: 1)
        )
        .animation(.easeOut(duration: 0.15), value: hovered)
        .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .onTapGesture {
            model.restoreHistoryItem(item)
        }
        .onHover { isHovering in
            hoveredItemID = isHovering ? item.id : (hoveredItemID == item.id ? nil : hoveredItemID)
        }
    }

    // MARK: - Hero content per type

    @ViewBuilder
    private func cardHero(for item: ClipboardHistoryItem, detail: ClipDetail) -> some View {
        switch detail.style {
        case .color(let color):
            VStack(alignment: .leading, spacing: 10) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color)
                    .frame(height: 44)
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.white.opacity(0.18), lineWidth: 1))
                Text((item.content ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case .link(let domain):
            VStack(alignment: .leading, spacing: 4) {
                Text(domain)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(item.content ?? "")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(3)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case .image:
            // Background renders the thumbnail; keep the hero empty so the
            // image reads full-bleed behind the footer.
            Color.clear

        case .text:
            Text(item.previewTitle)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(5)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    // MARK: - Background per type

    @ViewBuilder
    private func cardBackground(for item: ClipboardHistoryItem, detail: ClipDetail, hovered: Bool) -> some View {
        switch detail.style {
        case .image:
            if let image = item.thumbnailImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .overlay(
                        LinearGradient(
                            colors: [.black.opacity(0.15), .black.opacity(hovered ? 0.45 : 0.55)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
            } else {
                Color.white.opacity(hovered ? 0.09 : 0.05)
            }
        case .color(let color):
            // Faint wash of the color itself behind the card.
            ZStack {
                Color.white.opacity(hovered ? 0.07 : 0.04)
                LinearGradient(
                    colors: [color.opacity(hovered ? 0.28 : 0.22), color.opacity(0.05)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            }
        default:
            // Hover brightens the card's own fill instead of overlaying the
            // whole card with a translucent layer (which washed everything).
            Color.white.opacity(hovered ? 0.09 : 0.05)
        }
    }

    private func pinButton(for item: ClipboardHistoryItem) -> some View {
        Button {
            model.togglePin(for: item.id)
        } label: {
            Image(systemName: item.pinned ? "pin.fill" : "pin")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(item.pinned ? accent : .white.opacity(0.5))
                .rotationEffect(.degrees(item.pinned ? 0 : 45))
        }
        .buttonStyle(.plain)
        .help(item.pinned ? "Unpin" : "Keep")
    }
}

// MARK: - Content detection

/// Derives a richer, content-aware presentation from a clip, using only the
/// fields already on ClipboardHistoryItem. No model changes required.
private struct ClipDetail {
    enum Style {
        case text
        case link(domain: String)
        case image
        case color(Color)
    }

    let style: Style
    let symbol: String
    let meta: String

    init(item: ClipboardHistoryItem) {
        switch item.kind {
        case .image:
            style = .image
            symbol = "photo"
            meta = "IMAGE"

        case .link:
            let domain = ClipDetail.domain(from: item.content ?? "")
            style = .link(domain: domain)
            symbol = "link"
            meta = "LINK"

        case .text:
            let trimmed = (item.content ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if let color = ClipDetail.color(from: trimmed) {
                style = .color(color)
                symbol = "paintpalette"
                meta = "COLOR"
            } else {
                style = .text
                symbol = "text.alignleft"
                let count = trimmed.count
                meta = count == 1 ? "1 CHAR" : "\(count) CHARS"
            }
        }
    }

    /// Bare domain from a URL string, e.g. "github.com".
    static func domain(from urlString: String) -> String {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let host = URL(string: trimmed)?.host else {
            return trimmed
        }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    /// Parse a hex color like "#5CAAF2" from the content, if present.
    static func color(from string: String) -> Color? {
        var s = string.uppercased()
        guard s.hasPrefix("#") else { return nil }
        s.removeFirst()
        guard s.count == 6 || s.count == 8, let value = UInt64(s, radix: 16) else { return nil }
        let r, g, b: Double
        if s.count == 6 {
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
        } else {
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8) & 0xFF) / 255
        }
        return Color(red: r, green: g, blue: b)
    }
}

// MARK: - Scroll capture

/// Captures trackpad two-finger scroll / mouse-wheel anywhere inside the widget,
/// even when the cursor is over a card button. Uses a local NSEvent monitor so it
/// doesn't need to be the frontmost view (which would block card clicks).
private struct ScrollCatcher: NSViewRepresentable {
    let onScroll: (_ deltaX: CGFloat, _ deltaY: CGFloat) -> Void
    let onEnded: () -> Void

    func makeNSView(context: Context) -> ScrollCatcherView {
        let view = ScrollCatcherView()
        view.onScroll = onScroll
        view.onEnded = onEnded
        return view
    }

    func updateNSView(_ nsView: ScrollCatcherView, context: Context) {
        nsView.onScroll = onScroll
        nsView.onEnded = onEnded
    }

    static func dismantleNSView(_ nsView: ScrollCatcherView, coordinator: ()) {
        nsView.teardownMonitor()
    }

    final class ScrollCatcherView: NSView {
        var onScroll: ((CGFloat, CGFloat) -> Void)?
        var onEnded: (() -> Void)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil { installMonitor() } else { teardownMonitor() }
        }

        private func installMonitor() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self, let window = self.window,
                      event.window == window else { return event }

                // Only handle scroll when the cursor is within this widget's bounds.
                let pointInView = self.convert(event.locationInWindow, from: nil)
                guard self.bounds.contains(pointInView) else { return event }

                self.onScroll?(event.scrollingDeltaX, event.scrollingDeltaY)
                if event.phase == .ended || event.momentumPhase == .ended {
                    self.onEnded?()
                }
                // Swallow so the underlying scroll view doesn't also react.
                return nil
            }
        }

        func teardownMonitor() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }

        // Transparent to mouse clicks so card buttons receive taps.
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}

#Preview("Clipboard History Widget") {
    ClipboardHistoryWidgetPreview()
        .frame(width: 440, height: 170)
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
                kind: .text,
                content: "#5CAAF2",
                fingerprint: "color-preview"
            ),
            ClipboardHistoryItem(
                kind: .link,
                content: "https://github.com/nodescraper/interestingnotch",
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
