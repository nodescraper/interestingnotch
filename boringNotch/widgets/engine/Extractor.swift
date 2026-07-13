//
//  Extractor.swift
//  boringNotch
//
//  Created by Codex on 2026-07-13.
//

import Foundation

enum WidgetExtractorInput: Sendable {
    case raw(String)
    case value(WidgetValue)

    func requireString(for method: String) throws -> String {
        switch self {
        case .raw(let value):
            return value
        case .value(.string(let value)):
            return value
        case .value(let value):
            throw WidgetExtractorError.typeMismatch(
                method: method,
                expected: "string input",
                actual: String(describing: value)
            )
        }
    }
}

protocol Extractor: Sendable {
    var method: WidgetManifest.Extract.Method { get }
    func extract(from input: WidgetExtractorInput) throws -> WidgetValue
}

struct ExtractorPipeline: Sendable {
    let extractors: [any Extractor]

    init(extractors: [any Extractor]) {
        self.extractors = extractors
    }

    func extract(from rawOutput: String) throws -> WidgetValue {
        var currentInput = WidgetExtractorInput.raw(rawOutput)

        for extractor in extractors {
            currentInput = .value(try extractor.extract(from: currentInput))
        }

        switch currentInput {
        case .raw(let value):
            return .string(value)
        case .value(let value):
            return value
        }
    }
}

enum WidgetExtractorError: LocalizedError, Equatable, Sendable {
    case invalidJSON(String)
    case invalidPath(String)
    case pathNotFound(String)
    case invalidArrayIndex(String)
    case typeMismatch(method: String, expected: String, actual: String)

    var errorDescription: String? {
        switch self {
        case .invalidJSON(let details):
            return "Extractor received malformed JSON: \(details)"
        case .invalidPath(let path):
            return "Extractor path is invalid: \(path)"
        case .pathNotFound(let path):
            return "Extractor path was not found: \(path)"
        case .invalidArrayIndex(let value):
            return "Extractor expected a numeric array index, got '\(value)'"
        case .typeMismatch(let method, let expected, let actual):
            return "Extractor '\(method)' expected \(expected), got \(actual)"
        }
    }
}

struct RawExtractor: Extractor {
    let method: WidgetManifest.Extract.Method = .raw

    func extract(from input: WidgetExtractorInput) throws -> WidgetValue {
        .string(try input.requireString(for: "raw"))
    }
}

struct TrimExtractor: Extractor {
    let method: WidgetManifest.Extract.Method = .trim

    func extract(from input: WidgetExtractorInput) throws -> WidgetValue {
        let value = try input.requireString(for: "trim")
        return .string(value.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

struct LineCountExtractor: Extractor {
    let method: WidgetManifest.Extract.Method = .lineCount

    func extract(from input: WidgetExtractorInput) throws -> WidgetValue {
        let value = try input.requireString(for: "line-count")
        let count = value
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .count

        return .integer(count)
    }
}

struct JSONPathExtractor: Extractor {
    let method: WidgetManifest.Extract.Method = .jsonPath
    let path: String

    func extract(from input: WidgetExtractorInput) throws -> WidgetValue {
        let rawJSON = try input.requireString(for: "json-path")
        let data = Data(rawJSON.utf8)

        let rootObject: Any
        do {
            rootObject = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw WidgetExtractorError.invalidJSON(error.localizedDescription)
        }

        let components = try Self.parse(path: path)
        let resolved = try Self.resolve(components: components, in: rootObject, originalPath: path)
        return try Self.widgetValue(from: resolved, path: path)
    }

    private static func parse(path: String) throws -> [PathComponent] {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw WidgetExtractorError.invalidPath(path)
        }

        var result: [PathComponent] = []
        var currentKey = ""
        var index = trimmed.startIndex

        if trimmed[index] == "$" {
            index = trimmed.index(after: index)
        }

        while index < trimmed.endIndex {
            let character = trimmed[index]

            switch character {
            case ".":
                if !currentKey.isEmpty {
                    result.append(.key(currentKey))
                    currentKey.removeAll(keepingCapacity: true)
                }
                index = trimmed.index(after: index)
            case "[":
                if !currentKey.isEmpty {
                    result.append(.key(currentKey))
                    currentKey.removeAll(keepingCapacity: true)
                }

                guard let closing = trimmed[index...].firstIndex(of: "]") else {
                    throw WidgetExtractorError.invalidPath(path)
                }

                let rawIndex = String(trimmed[trimmed.index(after: index)..<closing])
                guard let numericIndex = Int(rawIndex) else {
                    throw WidgetExtractorError.invalidArrayIndex(rawIndex)
                }

                result.append(.index(numericIndex))
                index = trimmed.index(after: closing)
            default:
                currentKey.append(character)
                index = trimmed.index(after: index)
            }
        }

        if !currentKey.isEmpty {
            result.append(.key(currentKey))
        }

        if trimmed == "$" {
            return []
        }

        guard !result.isEmpty else {
            throw WidgetExtractorError.invalidPath(path)
        }

        return result
    }

    private static func resolve(
        components: [PathComponent],
        in rootObject: Any,
        originalPath: String
    ) throws -> Any {
        var current: Any = rootObject

        for component in components {
            switch component {
            case .key(let key):
                guard let dictionary = current as? [String: Any], let next = dictionary[key] else {
                    throw WidgetExtractorError.pathNotFound(originalPath)
                }
                current = next
            case .index(let index):
                guard let array = current as? [Any] else {
                    throw WidgetExtractorError.typeMismatch(
                        method: "json-path",
                        expected: "array at \(originalPath)",
                        actual: typeDescription(for: current)
                    )
                }
                guard array.indices.contains(index) else {
                    throw WidgetExtractorError.pathNotFound(originalPath)
                }
                current = array[index]
            }
        }

        return current
    }

    private static func widgetValue(from value: Any, path: String) throws -> WidgetValue {
        switch value {
        case is NSNull:
            return .null
        case let string as String:
            return .string(string)
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return .bool(number.boolValue)
            }

            let doubleValue = number.doubleValue
            if doubleValue.rounded(.towardZero) == doubleValue {
                return .integer(number.intValue)
            }

            return .double(doubleValue)
        case let array as [Any]:
            return .list(try array.map { try widgetValue(from: $0, path: path) })
        case let dictionary as [String: Any]:
            return .object(try dictionary.mapValues { try widgetValue(from: $0, path: path) })
        default:
            throw WidgetExtractorError.typeMismatch(
                method: "json-path",
                expected: "JSON value at \(path)",
                actual: typeDescription(for: value)
            )
        }
    }

    private static func typeDescription(for value: Any) -> String {
        String(describing: type(of: value))
    }

    private enum PathComponent: Equatable, Sendable {
        case key(String)
        case index(Int)
    }
}
