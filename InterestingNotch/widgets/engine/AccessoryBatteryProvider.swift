//
//  AccessoryBatteryProvider.swift
//  InterestingNotch
//
//  Created by Codex on 2026-07-13.
//

import Foundation
import IOBluetooth

enum AccessoryBatteryDeviceKind: String, Equatable, Sendable {
    case earbuds
    case headphones
    case keyboard
    case mouse
    case trackpad
    case speaker
    case phone
    case watch
    case generic

    var symbolName: String {
        switch self {
        case .earbuds:
            return "airpodspro"
        case .headphones:
            return "headphones"
        case .keyboard:
            return "keyboard"
        case .mouse:
            return "computermouse"
        case .trackpad:
            return "rectangle.and.hand.point.up.left.filled"
        case .speaker:
            return "speaker.wave.2"
        case .phone:
            return "iphone"
        case .watch:
            return "applewatch"
        case .generic:
            return "dot.radiowaves.left.and.right"
        }
    }
}

struct AccessoryBatteryComponents: Equatable, Sendable {
    let single: Int?
    let combined: Int?
    let left: Int?
    let right: Int?
    let casePercent: Int?

    var hasAnyValue: Bool {
        single != nil || combined != nil || left != nil || right != nil || casePercent != nil
    }

    var primaryPercent: Int? {
        if let left, let right {
            return min(left, right)
        }

        if let combined {
            return combined
        }

        if let single {
            return single
        }

        if let left {
            return left
        }

        if let right {
            return right
        }

        return casePercent
    }

    var cellValues: [(String, Int)] {
        var values: [(String, Int)] = []

        if let left {
            values.append(("L", left))
        }

        if let right {
            values.append(("R", right))
        }

        if let casePercent {
            values.append(("Case", casePercent))
        }

        if values.isEmpty, let combined {
            values.append(("All", combined))
        }

        if values.isEmpty, let single {
            values.append(("Battery", single))
        }

        return values
    }

    var widgetValue: WidgetValue {
        var payload: [String: WidgetValue] = [:]

        if let single {
            payload["single"] = .integer(single)
        }

        if let combined {
            payload["combined"] = .integer(combined)
        }

        if let left {
            payload["left"] = .integer(left)
        }

        if let right {
            payload["right"] = .integer(right)
        }

        if let casePercent {
            payload["case"] = .integer(casePercent)
        }

        return .object(payload)
    }

    init(
        single: Int? = nil,
        combined: Int? = nil,
        left: Int? = nil,
        right: Int? = nil,
        casePercent: Int? = nil
    ) {
        self.single = single
        self.combined = combined
        self.left = left
        self.right = right
        self.casePercent = casePercent
    }

    init?(widgetValue: WidgetValue?) {
        guard case .object(let object)? = widgetValue else { return nil }

        self.single = Self.integerValue(for: "single", in: object)
        self.combined = Self.integerValue(for: "combined", in: object)
        self.left = Self.integerValue(for: "left", in: object)
        self.right = Self.integerValue(for: "right", in: object)
        self.casePercent = Self.integerValue(for: "case", in: object)
    }

    private static func integerValue(for key: String, in object: [String: WidgetValue]) -> Int? {
        switch object[key] {
        case .integer(let value):
            return value
        case .double(let value):
            return Int(value.rounded())
        default:
            return nil
        }
    }
}

struct AccessoryBatteryDeviceSnapshot: Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let kind: AccessoryBatteryDeviceKind
    let isConnected: Bool
    let isCharging: Bool
    let battery: AccessoryBatteryComponents?

    var symbolName: String { kind.symbolName }
    var hasBatteryInfo: Bool { battery?.hasAnyValue == true }
    var primaryPercent: Int? { battery?.primaryPercent }
    var primaryDisplay: String { primaryPercent.map { "\($0)%" } ?? "no battery info" }
    var isCritical: Bool { (primaryPercent ?? 100) < 15 }
    var isAirPodsStyle: Bool { battery?.left != nil || battery?.right != nil || battery?.casePercent != nil }

    var widgetValue: WidgetValue {
        var payload: [String: WidgetValue] = [
            "id": .string(id),
            "name": .string(name),
            "kind": .string(kind.rawValue),
            "symbol": .string(symbolName),
            "connected": .bool(isConnected),
            "charging": .bool(isCharging),
        ]

        if let battery {
            payload["battery"] = battery.widgetValue
        }

        return .object(payload)
    }

    init(
        id: String,
        name: String,
        kind: AccessoryBatteryDeviceKind,
        isConnected: Bool,
        isCharging: Bool = false,
        battery: AccessoryBatteryComponents?
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.isConnected = isConnected
        self.isCharging = isCharging
        self.battery = battery
    }

    init?(widgetValue: WidgetValue) {
        guard case .object(let object) = widgetValue,
              case .string(let id)? = object["id"],
              case .string(let name)? = object["name"],
              case .string(let rawKind)? = object["kind"],
              let kind = AccessoryBatteryDeviceKind(rawValue: rawKind),
              case .bool(let isConnected)? = object["connected"],
              case .bool(let isCharging)? = object["charging"] else {
            return nil
        }

        self.id = id
        self.name = name
        self.kind = kind
        self.isConnected = isConnected
        self.isCharging = isCharging
        self.battery = AccessoryBatteryComponents(widgetValue: object["battery"])
    }
}

struct AccessoryBatterySnapshot: Equatable, Sendable {
    let devices: [AccessoryBatteryDeviceSnapshot]

    var reportingDevices: [AccessoryBatteryDeviceSnapshot] {
        devices.filter(\.hasBatteryInfo)
    }

    func primaryDevice(preferredID: String?) -> AccessoryBatteryDeviceSnapshot? {
        if let preferredID,
           let preferred = reportingDevices.first(where: { $0.id == preferredID }) {
            return preferred
        }

        if let airPods = reportingDevices.first(where: { $0.kind == .earbuds }) {
            return airPods
        }

        return reportingDevices.first
    }

    var widgetValue: WidgetValue {
        .object([
            "devices": .list(devices.map(\.widgetValue))
        ])
    }

    init(devices: [AccessoryBatteryDeviceSnapshot]) {
        self.devices = devices
    }

    init?(widgetValue: WidgetValue?) {
        guard case .object(let object)? = widgetValue,
              case .list(let list)? = object["devices"] else {
            return nil
        }

        self.devices = list.compactMap(AccessoryBatteryDeviceSnapshot.init(widgetValue:))
    }
}

struct AccessoryBatteryReading: Equatable, Sendable {
    let id: String
    let name: String
    let classOfDevice: UInt32
    let isConnected: Bool
    let isCharging: Bool
    let supportsMultiBattery: Bool
    let singlePercent: Int?
    let combinedPercent: Int?
    let leftPercent: Int?
    let rightPercent: Int?
    let casePercent: Int?
    let headsetLevel: Int?
}

enum AccessoryBatterySnapshotBuilder {
    static func makeSnapshot(from readings: [AccessoryBatteryReading]) -> AccessoryBatterySnapshot {
        var seen = Set<String>()
        let devices = readings.compactMap { reading -> AccessoryBatteryDeviceSnapshot? in
            guard seen.insert(reading.id).inserted else { return nil }
            return makeDevice(from: reading)
        }
        .sorted(by: deviceSort)

        return AccessoryBatterySnapshot(devices: devices)
    }

    static func makeDevice(from reading: AccessoryBatteryReading) -> AccessoryBatteryDeviceSnapshot? {
        let battery = batteryComponents(from: reading)
        let hasBatteryInfo = battery?.hasAnyValue == true

        guard reading.isConnected || hasBatteryInfo else {
            return nil
        }

        return AccessoryBatteryDeviceSnapshot(
            id: reading.id,
            name: reading.name,
            kind: deviceKind(for: reading),
            isConnected: reading.isConnected,
            isCharging: reading.isCharging,
            battery: battery
        )
    }

    static func batteryComponents(from reading: AccessoryBatteryReading) -> AccessoryBatteryComponents? {
        let single = normalizePercentage(reading.singlePercent)
        let combined = normalizePercentage(reading.combinedPercent)
        let left = normalizePercentage(reading.leftPercent)
        let right = normalizePercentage(reading.rightPercent)
        let casePercent = normalizePercentage(reading.casePercent)
        let headsetPercent = normalizeHeadsetLevel(reading.headsetLevel)

        let components = AccessoryBatteryComponents(
            single: single ?? headsetPercent,
            combined: combined,
            left: left,
            right: right,
            casePercent: casePercent
        )

        return components.hasAnyValue ? components : nil
    }

    static func normalizePercentage(_ value: Int?) -> Int? {
        guard let value, (1...100).contains(value) else { return nil }
        return value
    }

    static func normalizeHeadsetLevel(_ value: Int?) -> Int? {
        guard let value, (1...5).contains(value) else { return nil }
        return value * 20
    }

    static func deviceKind(for reading: AccessoryBatteryReading) -> AccessoryBatteryDeviceKind {
        let lowercasedName = reading.name.lowercased()
        if lowercasedName.contains("airpods") {
            return .earbuds
        }

        let majorClass = Int((reading.classOfDevice >> 8) & 0x1f)
        let minorClass = Int((reading.classOfDevice >> 2) & 0x3f)

        switch majorClass {
        case Int(kBluetoothDeviceClassMajorAudio):
            switch minorClass {
            case Int(kBluetoothDeviceClassMinorAudioHeadphones),
                 Int(kBluetoothDeviceClassMinorAudioHeadset),
                 Int(kBluetoothDeviceClassMinorAudioHandsFree):
                return .headphones
            case Int(kBluetoothDeviceClassMinorAudioLoudspeaker),
                 Int(kBluetoothDeviceClassMinorAudioPortable),
                 Int(kBluetoothDeviceClassMinorAudioHiFi):
                return .speaker
            default:
                return .headphones
            }
        case Int(kBluetoothDeviceClassMajorPeripheral):
            let peripheral1 = minorClass & 0x30
            if lowercasedName.contains("trackpad") {
                return .trackpad
            }
            switch peripheral1 {
            case Int(kBluetoothDeviceClassMinorPeripheral1Keyboard):
                return .keyboard
            case Int(kBluetoothDeviceClassMinorPeripheral1Pointing):
                return .mouse
            case Int(kBluetoothDeviceClassMinorPeripheral1Combo):
                return .keyboard
            default:
                if lowercasedName.contains("mouse") {
                    return .mouse
                }
                if lowercasedName.contains("keyboard") {
                    return .keyboard
                }
                return .generic
            }
        case Int(kBluetoothDeviceClassMajorPhone):
            return .phone
        case Int(kBluetoothDeviceClassMajorWearable):
            return lowercasedName.contains("watch") ? .watch : .generic
        default:
            if lowercasedName.contains("speaker") {
                return .speaker
            }
            if lowercasedName.contains("headphone") || lowercasedName.contains("buds") {
                return .headphones
            }
            return .generic
        }
    }

    private static func deviceSort(_ lhs: AccessoryBatteryDeviceSnapshot, _ rhs: AccessoryBatteryDeviceSnapshot) -> Bool {
        if lhs.isConnected != rhs.isConnected {
            return lhs.isConnected && !rhs.isConnected
        }

        if lhs.kind == .earbuds, rhs.kind != .earbuds {
            return true
        }

        if rhs.kind == .earbuds, lhs.kind != .earbuds {
            return false
        }

        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}

protocol AccessoryBatteryDeviceSourcing: Sendable {
    func pairedDevices() -> [AccessoryBatteryReading]
}

struct SystemAccessoryBatteryDeviceSource: AccessoryBatteryDeviceSourcing {
    /// Reads battery via `ioreg -a -r -k BatteryPercent` (plist output). This is
    /// the reliable public path for Apple/HID Bluetooth devices (Magic Mouse,
    /// Magic Keyboard, Magic Trackpad, AirPods) while they are connected. Generic
    /// third-party Bluetooth devices do not publish battery to any App-accessible
    /// API, so they cannot appear here.
    func pairedDevices() -> [AccessoryBatteryReading] {
        guard let plist = runIOReg() else { return [] }
        return Self.parse(plist: plist)
    }

    // MARK: - Run ioreg

    private func runIOReg() -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
        // -a = archive (plist), -r = rooted at matching, -k = only nodes with key,
        // -l = include properties. Match any node exposing BatteryPercent.
        process.arguments = ["-a", "-r", "-l", "-k", "BatteryPercent"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do { try process.run() } catch { return nil }

        let watchdog = DispatchWorkItem {
            if process.isRunning { process.terminate() }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 6, execute: watchdog)

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        watchdog.cancel()

        return data.isEmpty ? nil : data
    }

    // MARK: - Parse

    /// `ioreg -a` emits a plist whose root is an array of matched node dicts.
    static func parse(plist: Data) -> [AccessoryBatteryReading] {
        guard let root = try? PropertyListSerialization.propertyList(from: plist, format: nil) else {
            return []
        }

        var nodes: [[String: Any]] = []
        collectNodes(root, into: &nodes)

        var seen = Set<String>()
        return nodes.compactMap { node -> AccessoryBatteryReading? in
            guard node["BatteryPercent"] != nil else { return nil }

            let name = (node["Product"] as? String)
                ?? (node["BatteryName"] as? String)
                ?? "Bluetooth Device"
            let address = (node["DeviceAddress"] as? String)
                ?? (node["SerialNumber"] as? String)
                ?? name
            guard seen.insert(address).inserted else { return nil }

            let main = intValue(node["BatteryPercent"])
            let left = intValue(node["BatteryPercentLeft"])
            let right = intValue(node["BatteryPercentRight"])
            let casePercent = intValue(node["BatteryPercentCase"])

            return AccessoryBatteryReading(
                id: address,
                name: name,
                classOfDevice: 0,   // deviceKind() falls back to name heuristics
                isConnected: true,  // ioreg only lists active/connected HID nodes
                isCharging: isCharging(node),
                supportsMultiBattery: left != nil || right != nil || casePercent != nil,
                singlePercent: (left == nil && right == nil && casePercent == nil) ? main : nil,
                combinedPercent: nil,
                leftPercent: left,
                rightPercent: right,
                casePercent: casePercent,
                headsetLevel: nil
            )
        }
    }

    /// Walk the plist tree; ioreg nests children under "IORegistryEntryChildren".
    private static func collectNodes(_ object: Any, into nodes: inout [[String: Any]]) {
        if let dict = object as? [String: Any] {
            nodes.append(dict)
            if let children = dict["IORegistryEntryChildren"] as? [Any] {
                for child in children { collectNodes(child, into: &nodes) }
            }
        } else if let array = object as? [Any] {
            for element in array { collectNodes(element, into: &nodes) }
        }
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let i = value as? Int { return (0...100).contains(i) ? i : nil }
        if let n = value as? NSNumber { let i = n.intValue; return (0...100).contains(i) ? i : nil }
        if let s = value as? String { let d = s.filter(\.isNumber); if let i = Int(d), (0...100).contains(i) { return i } }
        return nil
    }

    private static func isCharging(_ node: [String: Any]) -> Bool {
        for key in ["BatteryIsCharging", "AppleRawExternalConnected", "ExternalConnected"] {
            if let b = node[key] as? Bool, b { return true }
            if let n = node[key] as? NSNumber, n.boolValue { return true }
        }
        if let t = node["Transport"] as? String, t == "USB" { return true }
        return false
    }
}

actor AccessoryBatteryProvider: FrameworkDataProviding {
    static let api = "accessory-battery"

    let api: String = AccessoryBatteryProvider.api

    private let source: any AccessoryBatteryDeviceSourcing

    init(source: (any AccessoryBatteryDeviceSourcing)? = nil) {
        self.source = source ?? SystemAccessoryBatteryDeviceSource()
    }

    func fetch() async throws -> WidgetValue {
        AccessoryBatterySnapshotBuilder
            .makeSnapshot(from: source.pairedDevices())
            .widgetValue
    }
}
