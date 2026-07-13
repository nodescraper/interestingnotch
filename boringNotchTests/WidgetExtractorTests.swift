//
//  WidgetExtractorTests.swift
//  boringNotchTests
//
//  Created by Codex on 2026-07-13.
//

import XCTest
@testable import boringNotch

final class WidgetExtractorTests: XCTestCase {
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
}
