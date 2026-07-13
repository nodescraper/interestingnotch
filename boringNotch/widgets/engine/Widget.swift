//
//  Widget.swift
//  boringNotch
//
//  Created by Codex on 2026-07-13.
//

import SwiftUI

enum WidgetStatus: Equatable, Sendable {
    case loading
    case ok
    case error(String)
    case disabled
}

enum WidgetConfigurationError: LocalizedError, Equatable, Sendable {
    case unsupportedChannelType(WidgetManifest.Source.ChannelType)
    case unsupportedExtractorMethod(WidgetManifest.Extract.Method)
    case missingJSONPath

    var errorDescription: String? {
        switch self {
        case .unsupportedChannelType(let type):
            return "Widget source type '\(type.rawValue)' is not supported yet."
        case .unsupportedExtractorMethod(let method):
            return "Widget extractor '\(method.rawValue)' is not supported yet."
        case .missingJSONPath:
            return "Widget json-path extractor is missing a path."
        }
    }
}

@MainActor
final class Widget: ObservableObject {
    let id: String
    let manifest: WidgetManifest
    let executor: any ChannelExecutor
    let extractor: ExtractorPipeline

    @Published var lastValue: WidgetValue?
    @Published var status: WidgetStatus

    init(
        manifest: WidgetManifest,
        executor: (any ChannelExecutor)? = nil,
        extractor: ExtractorPipeline? = nil,
        lastValue: WidgetValue? = nil,
        status: WidgetStatus = .loading
    ) throws {
        self.id = manifest.id
        self.manifest = manifest
        self.executor = try executor ?? WidgetRuntimeResolver.makeExecutor(for: manifest)
        self.extractor = try extractor ?? WidgetRuntimeResolver.makeExtractorPipeline(for: manifest)
        self.lastValue = lastValue
        self.status = status
    }

    var interval: TimeInterval { manifest.source.interval }
    var timeout: TimeInterval? { manifest.source.timeout }
    var sourceType: WidgetManifest.Source.ChannelType { manifest.source.type }
    var extractorMethod: WidgetManifest.Extract.Method { manifest.extract.method }

    var resolvedColor: Color {
        guard case .string(let rawColor)? = manifest.render.slots["color"] else {
            return ColorToken.accent.resolve()
        }

        return ColorToken(rawValue: rawColor).resolve()
    }
}

private enum WidgetRuntimeResolver {
    static func makeExecutor(for manifest: WidgetManifest) throws -> any ChannelExecutor {
        switch manifest.source.type {
        case .command:
            return CommandExecutor()
        case .http, .framework:
            throw WidgetConfigurationError.unsupportedChannelType(manifest.source.type)
        }
    }

    static func makeExtractorPipeline(for manifest: WidgetManifest) throws -> ExtractorPipeline {
        ExtractorPipeline(extractors: [try makeExtractor(for: manifest.extract)])
    }

    private static func makeExtractor(for extract: WidgetManifest.Extract) throws -> any Extractor {
        switch extract.method {
        case .raw:
            return RawExtractor()
        case .trim:
            return TrimExtractor()
        case .lineCount:
            return LineCountExtractor()
        case .jsonPath:
            guard let path = extract.path, !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw WidgetConfigurationError.missingJSONPath
            }
            return JSONPathExtractor(path: path)
        case .regex, .firstLine, .map:
            throw WidgetConfigurationError.unsupportedExtractorMethod(extract.method)
        }
    }
}
