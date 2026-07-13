//
//  ClipboardHistoryWidgetModel.swift
//  boringNotch
//
//  Created by Codex on 2026-07-13.
//

import AppKit
import CryptoKit
import Defaults
import Foundation
import SwiftUI

enum ClipboardHistoryItemKind: String, Codable, Equatable, Hashable, Sendable {
    case text
    case link
    case image

    var title: String {
        switch self {
        case .text:
            return "Text"
        case .link:
            return "Link"
        case .image:
            return "Image"
        }
    }

    var symbolName: String {
        switch self {
        case .text:
            return "text.alignleft"
        case .link:
            return "link"
        case .image:
            return "photo"
        }
    }
}

struct ClipboardHistoryItem: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: String
    let kind: ClipboardHistoryItemKind
    let content: String?
    let imagePNGData: Data?
    let fingerprint: String
    let createdAt: Date
    var pinned: Bool

    init(
        id: String = UUID().uuidString,
        kind: ClipboardHistoryItemKind,
        content: String? = nil,
        imagePNGData: Data? = nil,
        fingerprint: String,
        createdAt: Date = Date(),
        pinned: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.content = content
        self.imagePNGData = imagePNGData
        self.fingerprint = fingerprint
        self.createdAt = createdAt
        self.pinned = pinned
    }

    var previewTitle: String {
        switch kind {
        case .text:
            return content ?? ""
        case .link:
            return content ?? ""
        case .image:
            return "Image clipboard item"
        }
    }

    var previewSubtitle: String {
        switch kind {
        case .text:
            return "Tap to copy again"
        case .link:
            return "Tap to copy link"
        case .image:
            return pinned ? "Pinned image" : "Tap to copy image again"
        }
    }

    var thumbnailImage: NSImage? {
        guard let imagePNGData else { return nil }
        return NSImage(data: imagePNGData)
    }
}

struct ClipboardPasteboardSnapshot: Sendable {
    let changeCount: Int
    let typeIdentifiers: [String]
    let string: String?
    let url: URL?
    let image: NSImage?
}

enum ClipboardCaptureDecision: Equatable, Sendable {
    case capture(ClipboardHistoryItem)
    case skipConcealed
    case skipUnsupported
    case skipDuplicate
}

enum ClipboardHistoryPrivacyFilter {
    static let concealedTypeIdentifiers: Set<String> = [
        "org.nspasteboard.ConcealedType",
        "org.nspasteboard.TransientType",
        "de.petermaurer.TransientPasteboardType",
        "com.agilebits.onepassword",
    ]

    static func shouldCapture(typeIdentifiers: [String]) -> Bool {
        let lowered = Set(typeIdentifiers.map { $0.lowercased() })

        return concealedTypeIdentifiers.allSatisfy { concealed in
            !lowered.contains(concealed.lowercased())
        }
    }
}

enum ClipboardLinkDetector {
    static func resolvedURL(from string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let range = NSRange(location: 0, length: trimmed.utf16.count)
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: trimmed, options: [], range: range) ?? []

        guard let first = matches.first, first.range == range, let url = first.url else {
            return nil
        }

        return url
    }
}

enum ClipboardImageThumbnailer {
    static let maxDimension: CGFloat = 220

    static func thumbnailPNGData(from image: NSImage, maxDimension: CGFloat = maxDimension) -> Data? {
        guard let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(maxDimension),
            pixelsHigh: Int(maxDimension),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }

        representation.size = CGSize(width: maxDimension, height: maxDimension)

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }

        guard let context = NSGraphicsContext(bitmapImageRep: representation) else {
            return nil
        }

        NSGraphicsContext.current = context

        let fittedRect = aspectFitRect(
            imageSize: image.size,
            boundingSize: CGSize(width: maxDimension, height: maxDimension)
        )
        image.draw(in: fittedRect)

        return representation.representation(using: .png, properties: [:])
    }

    private static func aspectFitRect(imageSize: CGSize, boundingSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGRect(origin: .zero, size: boundingSize)
        }

        let scale = min(boundingSize.width / imageSize.width, boundingSize.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(
            x: (boundingSize.width - size.width) / 2,
            y: (boundingSize.height - size.height) / 2
        )

        return CGRect(origin: origin, size: size)
    }
}

enum ClipboardHistoryStore {
    static let limit = 50

    static func adding(_ item: ClipboardHistoryItem, to existing: [ClipboardHistoryItem]) -> [ClipboardHistoryItem] {
        guard existing.first?.fingerprint != item.fingerprint else {
            return existing
        }

        var items = [item] + existing
        guard items.count > limit else { return items }

        var index = items.count - 1
        while items.count > limit, index >= 0 {
            if !items[index].pinned {
                items.remove(at: index)
            }
            index -= 1
        }

        return items
    }

    static func togglingPin(for itemID: String, in items: [ClipboardHistoryItem]) -> [ClipboardHistoryItem] {
        items.map { item in
            guard item.id == itemID else { return item }

            var updated = item
            updated.pinned.toggle()
            return updated
        }
    }

    static func clearing(_ items: [ClipboardHistoryItem]) -> [ClipboardHistoryItem] {
        _ = items
        return []
    }

    static func promotingItem(withFingerprint fingerprint: String, in items: [ClipboardHistoryItem]) -> [ClipboardHistoryItem] {
        guard let index = items.firstIndex(where: { $0.fingerprint == fingerprint }) else {
            return items
        }

        guard index != 0 else { return items }

        let item = items[index]
        var reordered = items
        reordered.remove(at: index)
        reordered.insert(item, at: 0)
        return reordered
    }
}

protocol ClipboardHistoryPersisting {
    func loadItems(for widgetID: String) -> [ClipboardHistoryItem]
    func saveItems(_ items: [ClipboardHistoryItem], for widgetID: String)
}

struct DefaultsClipboardHistoryPersistence: ClipboardHistoryPersisting {
    private typealias Payload = [String: [ClipboardHistoryItem]]

    func loadItems(for widgetID: String) -> [ClipboardHistoryItem] {
        guard
            let data = Defaults[.clipboardHistoryStoreData],
            let payload = try? JSONDecoder().decode(Payload.self, from: data)
        else {
            return []
        }

        return payload[widgetID] ?? []
    }

    func saveItems(_ items: [ClipboardHistoryItem], for widgetID: String) {
        var payload: Payload = [:]

        if
            let data = Defaults[.clipboardHistoryStoreData],
            let existing = try? JSONDecoder().decode(Payload.self, from: data)
        {
            payload = existing
        }

        payload[widgetID] = items
        Defaults[.clipboardHistoryStoreData] = try? JSONEncoder().encode(payload)
    }
}

protocol ClipboardPasteboardAccess {
    var changeCount: Int { get }
    func snapshot() -> ClipboardPasteboardSnapshot
    func copy(_ item: ClipboardHistoryItem)
}

struct SystemClipboardPasteboardAccess: ClipboardPasteboardAccess {
    private let pasteboard = NSPasteboard.general

    var changeCount: Int {
        pasteboard.changeCount
    }

    func snapshot() -> ClipboardPasteboardSnapshot {
        let url = (pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL])?.first
        let image = NSImage(pasteboard: pasteboard)

        return ClipboardPasteboardSnapshot(
            changeCount: pasteboard.changeCount,
            typeIdentifiers: pasteboard.types?.map(\.rawValue) ?? [],
            string: pasteboard.string(forType: .string),
            url: url,
            image: image
        )
    }

    func copy(_ item: ClipboardHistoryItem) {
        pasteboard.clearContents()

        switch item.kind {
        case .text, .link:
            if let content = item.content {
                pasteboard.setString(content, forType: .string)
            }
        case .image:
            if let image = item.thumbnailImage {
                pasteboard.writeObjects([image])
            }
        }
    }
}

enum ClipboardCaptureResolver {
    static func decision(
        from snapshot: ClipboardPasteboardSnapshot,
        existingItems: [ClipboardHistoryItem],
        now: Date = Date()
    ) -> ClipboardCaptureDecision {
        guard ClipboardHistoryPrivacyFilter.shouldCapture(typeIdentifiers: snapshot.typeIdentifiers) else {
            return .skipConcealed
        }

        let item: ClipboardHistoryItem?

        if let url = snapshot.url {
            let normalized = url.absoluteString
            item = ClipboardHistoryItem(
                kind: .link,
                content: normalized,
                fingerprint: fingerprint(for: "link:\(normalized)"),
                createdAt: now
            )
        } else if let string = snapshot.string?.trimmingCharacters(in: .whitespacesAndNewlines), !string.isEmpty {
            if let detectedURL = ClipboardLinkDetector.resolvedURL(from: string) {
                let normalized = detectedURL.absoluteString
                item = ClipboardHistoryItem(
                    kind: .link,
                    content: normalized,
                    fingerprint: fingerprint(for: "link:\(normalized)"),
                    createdAt: now
                )
            } else {
                item = ClipboardHistoryItem(
                    kind: .text,
                    content: string,
                    fingerprint: fingerprint(for: "text:\(string)"),
                    createdAt: now
                )
            }
        } else if
            let image = snapshot.image,
            let pngData = ClipboardImageThumbnailer.thumbnailPNGData(from: image)
        {
            item = ClipboardHistoryItem(
                kind: .image,
                imagePNGData: pngData,
                fingerprint: fingerprint(for: pngData),
                createdAt: now
            )
        } else {
            item = nil
        }

        guard let item else {
            return .skipUnsupported
        }

        guard existingItems.first?.fingerprint != item.fingerprint else {
            return .skipDuplicate
        }

        return .capture(item)
    }

    private static func fingerprint(for string: String) -> String {
        fingerprint(for: Data(string.utf8))
    }

    private static func fingerprint(for data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

@MainActor
final class ClipboardHistoryWidgetModel: ObservableObject, InteractiveWidgetRuntime {
    let interactiveKind: WidgetManifest.Interactive.Kind = .clipboardHistory
    let widgetID: String

    @Published private(set) var items: [ClipboardHistoryItem]

    private let pasteboard: any ClipboardPasteboardAccess
    private let persistence: any ClipboardHistoryPersisting
    private let now: @Sendable () -> Date
    private var lastObservedChangeCount: Int
    private var pollingTask: Task<Void, Never>?

    init(
        widgetID: String,
        items: [ClipboardHistoryItem]? = nil,
        pasteboard: (any ClipboardPasteboardAccess)? = nil,
        persistence: (any ClipboardHistoryPersisting)? = nil,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.widgetID = widgetID
        self.pasteboard = pasteboard ?? SystemClipboardPasteboardAccess()
        self.persistence = persistence ?? DefaultsClipboardHistoryPersistence()
        self.now = now
        self.items = items ?? (persistence ?? DefaultsClipboardHistoryPersistence()).loadItems(for: widgetID)
        self.lastObservedChangeCount = (pasteboard ?? SystemClipboardPasteboardAccess()).changeCount
        startPolling()
    }

    deinit {
        pollingTask?.cancel()
    }

    func clearHistory() {
        items = ClipboardHistoryStore.clearing(items)
        persist()
    }

    func togglePin(for itemID: String) {
        items = ClipboardHistoryStore.togglingPin(for: itemID, in: items)
        persist()
    }

    func restoreHistoryItem(_ item: ClipboardHistoryItem) {
        items = ClipboardHistoryStore.promotingItem(withFingerprint: item.fingerprint, in: items)
        persist()
        pasteboard.copy(item)
        lastObservedChangeCount = pasteboard.changeCount
    }

    func captureIfNeeded() {
        let snapshot = pasteboard.snapshot()
        guard snapshot.changeCount != lastObservedChangeCount else { return }
        lastObservedChangeCount = snapshot.changeCount

        switch ClipboardCaptureResolver.decision(from: snapshot, existingItems: items, now: now()) {
        case .capture(let item):
            items = ClipboardHistoryStore.adding(item, to: items)
            persist()
        case .skipConcealed, .skipUnsupported, .skipDuplicate:
            break
        }
    }

    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.captureIfNeeded()
                }
            }
        }
    }

    private func persist() {
        persistence.saveItems(items, for: widgetID)
    }
}
