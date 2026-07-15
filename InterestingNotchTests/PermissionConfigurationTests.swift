import Foundation
import XCTest
@testable import InterestingNotch

final class PermissionConfigurationTests: XCTestCase {
    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testEveryPrivacyDeepLinkIsValidAndTargetsSystemSettings() throws {
        for destination in SystemSettingsDestination.allCases {
            XCTAssertFalse(destination.candidateURLStrings.isEmpty)
            for value in destination.candidateURLStrings {
                let url = try XCTUnwrap(URL(string: value))
                XCTAssertEqual(url.scheme, "x-apple.systempreferences")
            }
        }
    }

    func testRequiredUsageDescriptionsArePresent() throws {
        let info = try plist(at: "InterestingNotch/Info.plist")
        let requiredKeys = [
            "NSCameraUsageDescription",
            "NSMicrophoneUsageDescription",
            "NSBluetoothAlwaysUsageDescription",
            "NSCalendarsFullAccessUsageDescription",
            "NSRemindersFullAccessUsageDescription",
        ]

        for key in requiredKeys {
            let value = try XCTUnwrap(info[key] as? String, "Missing \(key)")
            XCTAssertFalse(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertTrue(value.contains("InterestingNotch"))
        }
    }

    func testSandboxEntitlementsPermitRequestedHardwareAndData() throws {
        let entitlements = try plist(at: "InterestingNotch/InterestingNotch.entitlements")
        let requiredKeys = [
            "com.apple.security.device.audio-input",
            "com.apple.security.device.bluetooth",
            "com.apple.security.device.camera",
            "com.apple.security.personal-information.calendars",
        ]

        for key in requiredKeys {
            XCTAssertEqual(entitlements[key] as? Bool, true, "Missing entitlement \(key)")
        }
    }

    func testAccessibilityHelperIdentityIsDerivedFromMainApp() throws {
        let mainID = "com.nodescraper.interestingnotch"
        XCTAssertEqual(
            XPCHelperClient.serviceName(forMainBundleIdentifier: mainID),
            "com.nodescraper.interestingnotch.InterestingNotchXPCHelper"
        )

        let helperInfo = try plist(at: "InterestingNotchXPCHelper/Info.plist")
        XCTAssertEqual(helperInfo["CFBundleDisplayName"] as? String, "InterestingNotch")

        let project = try String(
            contentsOf: repositoryRoot.appendingPathComponent("InterestingNotch.xcodeproj/project.pbxproj"),
            encoding: .utf8
        )
        XCTAssertTrue(project.contains("PRODUCT_BUNDLE_IDENTIFIER = \(mainID);"))
        XCTAssertTrue(project.contains("PRODUCT_BUNDLE_IDENTIFIER = \(mainID).InterestingNotchXPCHelper;"))
        XCTAssertFalse(project.contains("InterestingNotch Helper"))
        XCTAssertEqual(project.components(separatedBy: "ENABLE_RESOURCE_ACCESS_AUDIO_INPUT = YES;").count - 1, 2)
        XCTAssertEqual(project.components(separatedBy: "ENABLE_RESOURCE_ACCESS_CAMERA = YES;").count - 1, 2)
        XCTAssertEqual(project.components(separatedBy: "ENABLE_RESOURCE_ACCESS_CALENDARS = YES;").count - 1, 2)
    }

    private func plist(at relativePath: String) throws -> [String: Any] {
        let data = try Data(contentsOf: repositoryRoot.appendingPathComponent(relativePath))
        return try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )
    }
}
