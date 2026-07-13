//
//  WidgetExtractorTests.swift
//  boringNotchTests
//
//  Created by Codex on 2026-07-13.
//

import AppKit
import SwiftUI
import XCTest
@testable import boringNotch

final class WidgetExtractorTests: XCTestCase {
    @MainActor
    private func makeWidgetManifest(
        extractMethod: WidgetManifest.Extract.Method = .trim,
        extractPath: String? = nil,
        color: String = "good"
    ) -> WidgetManifest {
        WidgetManifest(
            schema: 1,
            kind: .data,
            id: "git-status",
            name: "Git Status",
            author: "NodeScraper",
            source: .init(
                type: .command,
                run: "git status --short",
                url: nil,
                method: nil,
                headers: nil,
                api: nil,
                interval: 10,
                timeout: 5,
                cwd: nil,
                env: nil
            ),
            extract: .init(
                method: extractMethod,
                pattern: nil,
                path: extractPath,
                table: nil
            ),
            render: .init(
                template: .iconLabel,
                slots: [
                    "icon": .string("arrow.triangle.branch"),
                    "label": .string("$value changed"),
                    "color": .string(color),
                ]
            ),
            onTap: nil,
            permissions: nil
        )
    }

    func testRawExtractorPassesThroughString() throws {
        let result = try RawExtractor().extract(from: .raw("hello"))
        XCTAssertEqual(result, .string("hello"))
    }

    func testTrimExtractorReturnsEmptyStringForWhitespaceOnlyInput() throws {
        let result = try TrimExtractor().extract(from: .raw("  \n\t  "))
        XCTAssertEqual(result, .string(""))
    }

    func testTrimExtractorLeavesCleanInputUnchanged() throws {
        let result = try TrimExtractor().extract(from: .raw("already-clean"))
        XCTAssertEqual(result, .string("already-clean"))
    }

    func testLineCountReturnsZeroForEmptyString() throws {
        let result = try LineCountExtractor().extract(from: .raw(""))
        XCTAssertEqual(result, .integer(0))
    }

    func testLineCountIgnoresTrailingNewline() throws {
        let result = try LineCountExtractor().extract(from: .raw("one\ntwo\n"))
        XCTAssertEqual(result, .integer(2))
    }

    func testLineCountCountsNonEmptyLinesAcrossMultilineInput() throws {
        let result = try LineCountExtractor().extract(from: .raw("first\n\n second \nthird"))
        XCTAssertEqual(result, .integer(3))
    }

    func testJSONPathResolvesNestedObjectValue() throws {
        let extractor = JSONPathExtractor(path: "current.temperature_2m")
        let json = #"{"current":{"temperature_2m":21.5}}"#

        let result = try extractor.extract(from: .raw(json))

        XCTAssertEqual(result, .double(21.5))
    }

    func testJSONPathResolvesArrayIndexValue() throws {
        let extractor = JSONPathExtractor(path: "$[0].conclusion")
        let json = #"[{"conclusion":"success"},{"conclusion":"failure"}]"#

        let result = try extractor.extract(from: .raw(json))

        XCTAssertEqual(result, .string("success"))
    }

    func testJSONPathReturnsObjectValuesWhenPathPointsAtObject() throws {
        let extractor = JSONPathExtractor(path: "session")
        let json = #"{"session":{"percent_used":42,"history":[1,2]}}"#

        let result = try extractor.extract(from: .raw(json))

        XCTAssertEqual(
            result,
            .object([
                "percent_used": .integer(42),
                "history": .list([.integer(1), .integer(2)]),
            ])
        )
    }

    func testJSONPathThrowsWhenPathIsMissing() throws {
        let extractor = JSONPathExtractor(path: "session.missing")
        let json = #"{"session":{"percent_used":42}}"#

        XCTAssertThrowsError(try extractor.extract(from: .raw(json))) { error in
            XCTAssertEqual(error as? WidgetExtractorError, .pathNotFound("session.missing"))
        }
    }

    func testJSONPathThrowsWhenJSONIsMalformed() throws {
        let extractor = JSONPathExtractor(path: "session.percent_used")

        XCTAssertThrowsError(try extractor.extract(from: .raw("{not json"))) { error in
            guard case .invalidJSON = error as? WidgetExtractorError else {
                return XCTFail("Expected invalidJSON error, got \(error)")
            }
        }
    }

    func testJSONPathThrowsWhenArrayIndexIsNotNumeric() throws {
        let extractor = JSONPathExtractor(path: "$[first].conclusion")
        let json = #"[{"conclusion":"success"}]"#

        XCTAssertThrowsError(try extractor.extract(from: .raw(json))) { error in
            XCTAssertEqual(error as? WidgetExtractorError, .invalidArrayIndex("first"))
        }
    }

    func testExtractorPipelineChainsTrimAndLineCount() throws {
        let pipeline = ExtractorPipeline(extractors: [TrimExtractor(), LineCountExtractor()])

        let result = try pipeline.extract(from: "\n one \n two \n")

        XCTAssertEqual(result, .integer(2))
    }

    func testCommandExecutorReturnsStdoutForAllowlistedCommand() async throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let fileURL = temporaryDirectory.appendingPathComponent("widget executor test.txt")
        try "executor-output".write(to: fileURL, atomically: true, encoding: .utf8)

        let source = WidgetManifest.Source(
            type: .command,
            run: #"cat "\#(fileURL.path)""#,
            url: nil,
            method: nil,
            headers: nil,
            api: nil,
            interval: 1,
            timeout: 1,
            cwd: nil,
            env: nil
        )

        let output = try await CommandExecutor().run(source: source)
        XCTAssertEqual(output, "executor-output")
    }

    func testCommandExecutorRejectsNonAllowlistedExecutable() async {
        let source = WidgetManifest.Source(
            type: .command,
            run: "perl -e 'print 1'",
            url: nil,
            method: nil,
            headers: nil,
            api: nil,
            interval: 1,
            timeout: 1,
            cwd: nil,
            env: nil
        )

        do {
            _ = try await CommandExecutor().run(source: source)
            XCTFail("Expected non-allowlisted command to be rejected.")
        } catch {
            XCTAssertEqual(error as? ChannelExecutorError, .executableNotAllowed("perl"))
        }
    }

    func testCommandExecutorTimesOutLongRunningCommand() async {
        let source = WidgetManifest.Source(
            type: .command,
            run: #"osascript -e "delay 2""#,
            url: nil,
            method: nil,
            headers: nil,
            api: nil,
            interval: 1,
            timeout: 0.1,
            cwd: nil,
            env: nil
        )

        do {
            _ = try await CommandExecutor().run(source: source)
            XCTFail("Expected command to time out.")
        } catch {
            XCTAssertEqual(error as? ChannelExecutorError, .timedOut(0.1))
        }
    }

    func testCommandExecutorReturnsTypedErrorForNonZeroExit() async {
        let source = WidgetManifest.Source(
            type: .command,
            run: "git --definitely-not-a-real-option",
            url: nil,
            method: nil,
            headers: nil,
            api: nil,
            interval: 1,
            timeout: 1,
            cwd: nil,
            env: nil
        )

        do {
            _ = try await CommandExecutor().run(source: source)
            XCTFail("Expected non-zero exit.")
        } catch {
            guard case .nonZeroExit(let executable, let code, let stderr) = error as? ChannelExecutorError else {
                return XCTFail("Expected nonZeroExit error, got \(error)")
            }

            XCTAssertEqual(executable, "git")
            XCTAssertNotEqual(code, 0)
            XCTAssertFalse(stderr.isEmpty)
        }
    }

    @MainActor
    func testWidgetSelectsCommandExecutorAndConfiguredExtractor() throws {
        let widget = try Widget(manifest: makeWidgetManifest(extractMethod: .trim))

        XCTAssertEqual(widget.executor.channelType, .command)
        XCTAssertEqual(widget.extractor.extractors.map(\.method), [.trim])
    }

    @MainActor
    func testWidgetStartsLoadingWithNilValue() throws {
        let widget = try Widget(manifest: makeWidgetManifest())

        XCTAssertNil(widget.lastValue)
        XCTAssertEqual(widget.status, .loading)
    }

    @MainActor
    func testWidgetResolvedColorUsesManifestColorToken() throws {
        let widget = try Widget(manifest: makeWidgetManifest(color: "good"))

        XCTAssertEqual(
            resolvedNSColor(from: widget.resolvedColor),
            resolvedNSColor(from: ColorToken.good.resolve())
        )
    }

    @MainActor
    private func resolvedNSColor(from color: Color) -> NSColor? {
        NSColor(color).usingColorSpace(.deviceRGB)
    }
}
