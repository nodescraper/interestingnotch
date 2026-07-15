//
//  WidgetStore.swift
//  InterestingNotch
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
    case missingSource
    case missingExtract
    case missingInteractiveConfiguration
    case missingCommandRun

    var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let schema):
            return "Widget schema version \(schema) is not supported."
        case .missingSource:
            return "Data widgets must define a source."
        case .missingExtract:
            return "Data widgets must define an extract block."
        case .missingInteractiveConfiguration:
            return "Interactive widgets must define an interactive configuration."
        case .missingCommandRun:
            return "Command widgets must define a run string."
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
    private let seedBundledManifests: Bool
    let widgetsDirectoryURL: URL

    init(
        fileManager: FileManager = .default,
        widgetsDirectoryURL: URL? = nil,
        engine: (any WidgetStoreEngine)? = nil,
        seedBundledManifests: Bool = true
    ) {
        self.fileManager = fileManager
        self.engine = engine ?? WidgetEngine.shared
        self.seedBundledManifests = seedBundledManifests
        self.widgetsDirectoryURL = widgetsDirectoryURL ?? Self.defaultWidgetsDirectoryURL(fileManager: fileManager)
    }

    @discardableResult
    func loadAll() -> WidgetStoreLoadResult {
        var failures: [WidgetStoreLoadFailure] = []

        do {
            try fileManager.createDirectory(at: widgetsDirectoryURL, withIntermediateDirectories: true)
            if seedBundledManifests {
                try WidgetLibrary.seedBundledManifestsIfNeeded(into: widgetsDirectoryURL, fileManager: fileManager)
            }
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
                if manifest.id == "accessory-battery" {
                    // Removed bundled widget: clean up manifests created by older builds.
                    try? fileManager.removeItem(at: fileURL)
                    continue
                }
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

        switch manifest.kind {
        case .data:
            guard let source = manifest.source else {
                throw WidgetStoreError.missingSource
            }
            guard manifest.extract != nil else {
                throw WidgetStoreError.missingExtract
            }
            if source.type == .command {
                guard let run = source.run?.trimmingCharacters(in: .whitespacesAndNewlines), !run.isEmpty else {
                    throw WidgetStoreError.missingCommandRun
                }
            }
        case .interactive:
            guard manifest.interactive != nil else {
                throw WidgetStoreError.missingInteractiveConfiguration
            }
        }
    }

    private static func defaultWidgetsDirectoryURL(fileManager: FileManager) -> URL {
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true)

        return appSupportURL
            .appendingPathComponent("InterestingNotch", isDirectory: true)
            .appendingPathComponent("widgets", isDirectory: true)
    }
}
