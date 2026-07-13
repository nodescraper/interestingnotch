//
//  WidgetExtractorTests.swift
//  boringNotchTests
//
//  Created by Codex on 2026-07-13.
//

import AppKit
import Defaults
import SwiftUI
import XCTest
@testable import boringNotch

final class WidgetExtractorTests: XCTestCase {
    @MainActor
    private func makeWidgetManifest(
        id: String = "git-status",
        extractMethod: WidgetManifest.Extract.Method = .trim,
        command: String = "git status --short",
        interval: TimeInterval = 10,
        extractPath: String? = nil,
        color: String = "good"
    ) -> WidgetManifest {
        WidgetManifest(
            schema: 1,
            kind: .data,
            id: id,
            name: "Git Status",
            author: "NodeScraper",
            source: .init(
                type: .command,
                run: command,
                url: nil,
                method: nil,
                headers: nil,
                api: nil,
                interval: interval,
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
    func testWidgetEnginePopulatesValueAndMarksWidgetOKAfterTick() async throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let fileURL = temporaryDirectory.appendingPathComponent("engine-value.txt")
        try "engine-output".write(to: fileURL, atomically: true, encoding: .utf8)

        let widget = try Widget(
            manifest: makeWidgetManifest(
                extractMethod: .raw,
                command: #"cat "\#(fileURL.path)""#
            )
        )
        let engine = WidgetEngine()
        defer { engine.load([]) }

        engine.load([widget])

        try await waitUntil {
            widget.status == .ok && widget.lastValue == .string("engine-output")
        }
    }

    @MainActor
    func testWidgetEngineIsolatesFailuresBetweenWidgets() async throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let fileURL = temporaryDirectory.appendingPathComponent("healthy-widget.txt")
        try "healthy-output".write(to: fileURL, atomically: true, encoding: .utf8)

        let healthyWidget = try Widget(
            manifest: makeWidgetManifest(
                id: "healthy-widget",
                extractMethod: .raw,
                command: #"cat "\#(fileURL.path)""#
            )
        )
        let failingWidget = try Widget(
            manifest: makeWidgetManifest(
                id: "failing-widget",
                command: "git --definitely-not-a-real-option"
            )
        )
        let engine = WidgetEngine()
        defer { engine.load([]) }

        engine.load([failingWidget, healthyWidget])

        try await waitUntil {
            if case .error = failingWidget.status {
                return healthyWidget.status == .ok && healthyWidget.lastValue == .string("healthy-output")
            }
            return false
        }
    }

    @MainActor
    func testWidgetEngineReloadCancelsOldPollingLoops() async throws {
        let executor = CountingExecutor()
        let widget = try Widget(
            manifest: makeWidgetManifest(
                id: "counting-widget",
                extractMethod: .raw,
                interval: 0.05
            ),
            executor: executor,
            extractor: ExtractorPipeline(extractors: [RawExtractor()])
        )
        let engine = WidgetEngine()

        engine.load([widget])
        try await waitUntil {
            await executor.count >= 2
        }

        engine.load([])
        let countAfterCancellation = await executor.count
        try? await Task.sleep(nanoseconds: 150_000_000)
        let finalCount = await executor.count

        XCTAssertEqual(finalCount, countAfterCancellation)
    }

    @MainActor
    func testWidgetStoreLoadsValidManifestsIntoWidgetsAndEngine() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try writeManifest(
            makeWidgetManifest(id: "widget-one"),
            named: "widget-one.notchwidget.json",
            into: temporaryDirectory
        )
        try writeManifest(
            makeWidgetManifest(id: "widget-two", extractMethod: .raw),
            named: "widget-two.notchwidget.json",
            into: temporaryDirectory
        )

        let engine = RecordingWidgetStoreEngine()
        let store = WidgetStore(widgetsDirectoryURL: temporaryDirectory, engine: engine)

        let result = store.loadAll()

        XCTAssertEqual(result.widgets.map(\.id), ["widget-one", "widget-two"])
        XCTAssertTrue(result.failures.isEmpty)
        XCTAssertEqual(engine.loadedWidgetIDs, ["widget-one", "widget-two"])
    }

    @MainActor
    func testWidgetStoreReportsInvalidFilesWhileLoadingValidOnes() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try writeManifest(
            makeWidgetManifest(id: "healthy-widget"),
            named: "healthy-widget.notchwidget.json",
            into: temporaryDirectory
        )

        let malformedURL = temporaryDirectory.appendingPathComponent("malformed.notchwidget.json")
        try "{not valid json".write(to: malformedURL, atomically: true, encoding: .utf8)

        var unknownSchemaManifest = makeWidgetManifest(id: "future-widget")
        unknownSchemaManifest = WidgetManifest(
            schema: 2,
            kind: unknownSchemaManifest.kind,
            id: unknownSchemaManifest.id,
            name: unknownSchemaManifest.name,
            author: unknownSchemaManifest.author,
            source: unknownSchemaManifest.source,
            extract: unknownSchemaManifest.extract,
            render: unknownSchemaManifest.render,
            onTap: unknownSchemaManifest.onTap,
            permissions: unknownSchemaManifest.permissions
        )
        try writeManifest(
            unknownSchemaManifest,
            named: "future-widget.notchwidget.json",
            into: temporaryDirectory
        )

        let engine = RecordingWidgetStoreEngine()
        let store = WidgetStore(widgetsDirectoryURL: temporaryDirectory, engine: engine)

        let result = store.loadAll()

        XCTAssertEqual(result.widgets.map(\.id), ["healthy-widget"])
        XCTAssertEqual(
            Set(result.failures.map { $0.fileURL.lastPathComponent }),
            ["future-widget.notchwidget.json", "malformed.notchwidget.json"]
        )
        XCTAssertEqual(engine.loadedWidgetIDs, ["healthy-widget"])
    }

    @MainActor
    func testWidgetStoreCreatesMissingDirectoryAndReturnsEmptyResult() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let missingDirectory = temporaryDirectory.appendingPathComponent("widgets", isDirectory: true)
        let engine = RecordingWidgetStoreEngine()
        let store = WidgetStore(widgetsDirectoryURL: missingDirectory, engine: engine)

        let result = store.loadAll()

        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: missingDirectory.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
        XCTAssertTrue(result.widgets.isEmpty)
        XCTAssertTrue(result.failures.isEmpty)
        XCTAssertEqual(engine.loadedWidgetIDs, [])
    }

    @MainActor
    func testWidgetLaunchLoaderLoadsWidgetsIntoEngineFromStore() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try writeManifest(
            makeWidgetManifest(id: "launch-widget", extractMethod: .raw),
            named: "launch-widget.notchwidget.json",
            into: temporaryDirectory
        )

        let engine = RecordingWidgetStoreEngine()
        let store = WidgetStore(widgetsDirectoryURL: temporaryDirectory, engine: engine)
        let loader = WidgetLaunchLoader(store: store)

        let result = loader.loadWidgets()

        XCTAssertEqual(result.widgets.map(\.id), ["launch-widget"])
        XCTAssertEqual(engine.loadedWidgetIDs, ["launch-widget"])
    }

    func testWidgetSlotRendererResolvesValuePlaceholder() {
        let result = WidgetSlotRenderer.resolveText("$value updates", value: .integer(3))

        XCTAssertEqual(result, "3 updates")
    }

    func testWidgetSlotRendererUsesDashPlaceholderWhenValueMissing() {
        let result = WidgetSlotRenderer.resolveText("$value updates", value: nil)

        XCTAssertEqual(result, "— updates")
    }

    func testWidgetSlotRendererConvertsStringValuesToNumbers() {
        let result = WidgetSlotRenderer.numericValue(from: .string(" 42.5 "))

        XCTAssertEqual(result, 42.5)
    }

    func testWidgetSlotRendererResolvesStringSlotTemplates() {
        let result = WidgetSlotRenderer.resolvedString(
            forSlotNamed: "label",
            in: ["label": .string("$value updates")],
            value: .integer(5),
            fallback: "Fallback"
        )

        XCTAssertEqual(result, "5 updates")
    }

    func testWidgetSlotRendererFallsBackWhenSlotMissing() {
        let result = WidgetSlotRenderer.resolvedString(
            forSlotNamed: "label",
            in: [:],
            value: .integer(5),
            fallback: "Fallback"
        )

        XCTAssertEqual(result, "Fallback")
    }

    func testPinnedWidgetIDsPersistInDefaults() {
        let originalValue = Defaults[.pinnedWidgetIDs]
        defer { Defaults[.pinnedWidgetIDs] = originalValue }

        Defaults[.pinnedWidgetIDs] = ["weather", "battery"]

        XCTAssertEqual(Defaults[.pinnedWidgetIDs], ["weather", "battery"])
    }

    func testWidgetPinStorePinsAndUnpinsWithoutDuplicates() {
        let pinned = WidgetPinStore.pin("weather", in: [])
        XCTAssertEqual(pinned, ["weather"])
        XCTAssertEqual(WidgetPinStore.pin("weather", in: pinned), ["weather"])
        XCTAssertEqual(
            WidgetPinStore.unpin("weather", in: ["weather", "battery"]),
            ["battery"]
        )
    }

    func testWidgetTabResolverDerivesTabsFromPinnedWidgetIDsInOrder() {
        let tabs = WidgetTabResolver.descriptors(
            pinnedWidgetIDs: ["battery", "git-status"],
            availableWidgets: [
                WidgetTabSource(id: "git-status", title: "Git Status", icon: "arrow.triangle.branch"),
                WidgetTabSource(id: "battery", title: "Battery", icon: "battery.100"),
            ]
        )

        XCTAssertEqual(tabs.map(\.id), ["battery", "git-status"])
        XCTAssertEqual(tabs.map(\.view), [.widget(id: "battery"), .widget(id: "git-status")])
    }

    func testWidgetTabResolverSkipsUnknownPinnedWidgetIDsSafely() {
        let tabs = WidgetTabResolver.descriptors(
            pinnedWidgetIDs: ["missing-widget", "git-status"],
            availableWidgets: [
                WidgetTabSource(id: "git-status", title: "Git Status", icon: "arrow.triangle.branch"),
            ]
        )

        XCTAssertEqual(tabs.map(\.id), ["git-status"])
    }

    @MainActor
    private func resolvedNSColor(from color: Color) -> NSColor? {
        NSColor(color).usingColorSpace(.deviceRGB)
    }

    private func waitUntil(
        timeout: TimeInterval = 1,
        pollInterval: UInt64 = 10_000_000,
        condition: @escaping @MainActor () async -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if await condition() {
                return
            }

            try await Task.sleep(nanoseconds: pollInterval)
        }

        XCTFail("Condition not met within \(timeout) seconds.")
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func writeManifest(_ manifest: WidgetManifest, named fileName: String, into directory: URL) throws {
        let fileURL = directory.appendingPathComponent(fileName)
        let data = try JSONEncoder().encode(manifest)
        try data.write(to: fileURL)
    }
}

private actor CountingExecutor: ChannelExecutor {
    let channelType: WidgetManifest.Source.ChannelType = .command

    private(set) var count = 0

    func run(source: WidgetManifest.Source) async throws -> String {
        count += 1
        return "count-\(count)"
    }
}

@MainActor
private final class RecordingWidgetStoreEngine: WidgetStoreEngine {
    private(set) var loadedWidgetIDs: [String] = []

    func load(_ widgets: [boringNotch.Widget]) {
        loadedWidgetIDs = widgets.map(\.id)
    }
}
