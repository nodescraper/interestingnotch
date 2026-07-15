//
//  Widget.swift
//  InterestingNotch
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
    case missingSource
    case missingExtract
    case missingInteractiveConfiguration
    case unsupportedChannelType(WidgetManifest.Source.ChannelType)
    case unsupportedExtractorMethod(WidgetManifest.Extract.Method)
    case unsupportedInteractiveType(WidgetManifest.Interactive.Kind)
    case missingJSONPath

    var errorDescription: String? {
        switch self {
        case .missingSource:
            return "Widget source configuration is missing."
        case .missingExtract:
            return "Widget extract configuration is missing."
        case .missingInteractiveConfiguration:
            return "Interactive widget configuration is missing."
        case .unsupportedChannelType(let type):
            return "Widget source type '\(type.rawValue)' is not supported yet."
        case .unsupportedExtractorMethod(let method):
            return "Widget extractor '\(method.rawValue)' is not supported yet."
        case .unsupportedInteractiveType(let type):
            return "Interactive widget '\(type.rawValue)' is not supported yet."
        case .missingJSONPath:
            return "Widget json-path extractor is missing a path."
        }
    }
}

@MainActor
final class Widget: ObservableObject {
    let id: String
    let manifest: WidgetManifest
    let executor: (any ChannelExecutor)?
    let extractor: ExtractorPipeline?
    let interactiveRuntime: (any InteractiveWidgetRuntime)?

    @Published var lastValue: WidgetValue?
    @Published var status: WidgetStatus

    init(
        manifest: WidgetManifest,
        executor: (any ChannelExecutor)? = nil,
        extractor: ExtractorPipeline? = nil,
        interactiveRuntime: (any InteractiveWidgetRuntime)? = nil,
        lastValue: WidgetValue? = nil,
        status: WidgetStatus? = nil
    ) throws {
        self.id = manifest.id
        self.manifest = manifest
        self.executor = try executor ?? WidgetRuntimeResolver.makeExecutor(for: manifest)
        self.extractor = try extractor ?? WidgetRuntimeResolver.makeExtractorPipeline(for: manifest)
        self.interactiveRuntime = try interactiveRuntime ?? WidgetRuntimeResolver.makeInteractiveRuntime(for: manifest)
        self.lastValue = lastValue
        self.status = status ?? WidgetRuntimeResolver.initialStatus(for: manifest)
    }

    var interval: TimeInterval { manifest.source?.interval ?? 0 }
    var timeout: TimeInterval? { manifest.source?.timeout }
    var sourceType: WidgetManifest.Source.ChannelType? { manifest.source?.type }
    var extractorMethod: WidgetManifest.Extract.Method? { manifest.extract?.method }
    var isPollingEnabled: Bool { manifest.kind == .data && executor != nil && extractor != nil }

    var resolvedColor: Color {
        guard case .string(let rawColor)? = manifest.render.slots["color"] else {
            return ColorToken.accent.resolve()
        }

        return ColorToken(rawValue: rawColor).resolve()
    }
}

@MainActor
private enum WidgetRuntimeResolver {
    static func initialStatus(for manifest: WidgetManifest) -> WidgetStatus {
        manifest.kind == .interactive ? .ok : .loading
    }

    static func makeExecutor(for manifest: WidgetManifest) throws -> (any ChannelExecutor)? {
        switch manifest.kind {
        case .data:
            guard let source = manifest.source else {
                throw WidgetConfigurationError.missingSource
            }

            switch source.type {
            case .command:
                return CommandExecutor()
            case .framework:
                return FrameworkExecutor()
            case .http:
                throw WidgetConfigurationError.unsupportedChannelType(source.type)
            }
        case .interactive:
            return nil
        }
    }

    static func makeExtractorPipeline(for manifest: WidgetManifest) throws -> ExtractorPipeline? {
        switch manifest.kind {
        case .data:
            guard let extract = manifest.extract else {
                throw WidgetConfigurationError.missingExtract
            }
            return ExtractorPipeline(extractors: [try makeExtractor(for: extract)])
        case .interactive:
            return nil
        }
    }

    static func makeInteractiveRuntime(for manifest: WidgetManifest) throws -> (any InteractiveWidgetRuntime)? {
        guard manifest.kind == .interactive else { return nil }
        guard let interactive = manifest.interactive else {
            throw WidgetConfigurationError.missingInteractiveConfiguration
        }

        switch interactive.type {
        case .calendar:
            return CalendarWidgetModel(widgetID: manifest.id)
        case .colorPicker:
            return ColorPickerWidgetModel(widgetID: manifest.id)
        case .timer:
            return TimerWidgetModel(widgetID: manifest.id)
        case .clipboardHistory:
            return ClipboardHistoryWidgetModel(widgetID: manifest.id)
        case .voiceRecorder:
            return VoiceRecorderWidgetModel(widgetID: manifest.id)
        }
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
