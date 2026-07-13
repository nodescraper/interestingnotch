//
//  WidgetStore.swift
//  boringNotch
//
//  Created by Codex on 2026-07-13.
//

import Foundation

struct WidgetStoreLoadFailure: Equatable, Sendable {
    let fileURL: URL
    let message: String
}

struct WidgetStoreLoadResult {
    let widgets: [Widget]
    let failures: [WidgetStoreLoadFailure]
}

enum WidgetStoreError: LocalizedError, Equatable, Sendable {
    case unsupportedSchema(Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let schema):
            return "Widget schema version \(schema) is not supported."
        }
    }
}

@MainActor
protocol WidgetStoreEngine: AnyObject {
    func load(_ widgets: [Widget])
}

extension WidgetEngine: WidgetStoreEngine {}

@MainActor
final class WidgetStore {
    static let shared = WidgetStore()

    private let fileManager: FileManager
    private let engine: any WidgetStoreEngine
    let widgetsDirectoryURL: URL

    init(
        fileManager: FileManager = .default,
        widgetsDirectoryURL: URL? = nil,
        engine: (any WidgetStoreEngine)? = nil
    ) {
        self.fileManager = fileManager
        self.engine = engine ?? WidgetEngine.shared
        self.widgetsDirectoryURL = widgetsDirectoryURL ?? Self.defaultWidgetsDirectoryURL(fileManager: fileManager)
    }

    @discardableResult
    func loadAll() -> WidgetStoreLoadResult {
        var failures: [WidgetStoreLoadFailure] = []

        do {
            try fileManager.createDirectory(at: widgetsDirectoryURL, withIntermediateDirectories: true)
        } catch {
            let failure = WidgetStoreLoadFailure(fileURL: widgetsDirectoryURL, message: error.localizedDescription)
            engine.load([])
            return WidgetStoreLoadResult(widgets: [], failures: [failure])
        }

        let manifestFiles: [URL]
        do {
            manifestFiles = try fileManager.contentsOfDirectory(
                at: widgetsDirectoryURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            .filter { $0.pathExtension == "json" && $0.lastPathComponent.hasSuffix(".notchwidget.json") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        } catch {
            let failure = WidgetStoreLoadFailure(fileURL: widgetsDirectoryURL, message: error.localizedDescription)
            engine.load([])
            return WidgetStoreLoadResult(widgets: [], failures: [failure])
        }

        var widgets: [Widget] = []

        for fileURL in manifestFiles {
            do {
                let data = try Data(contentsOf: fileURL)
                let manifest = try JSONDecoder().decode(WidgetManifest.self, from: data)
                try validate(manifest: manifest)
                widgets.append(try Widget(manifest: manifest))
            } catch {
                failures.append(
                    WidgetStoreLoadFailure(
                        fileURL: fileURL,
                        message: error.localizedDescription
                    )
                )
            }
        }

        engine.load(widgets)
        return WidgetStoreLoadResult(widgets: widgets, failures: failures)
    }

    private func validate(manifest: WidgetManifest) throws {
        guard manifest.schema == 1 else {
            throw WidgetStoreError.unsupportedSchema(manifest.schema)
        }
    }

    private static func defaultWidgetsDirectoryURL(fileManager: FileManager) -> URL {
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true)

        return appSupportURL
            .appendingPathComponent("boringNotch", isDirectory: true)
            .appendingPathComponent("widgets", isDirectory: true)
    }
}
