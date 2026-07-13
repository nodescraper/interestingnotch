//
//  SystemMonitorProvider.swift
//  boringNotch
//
//  Created by Codex on 2026-07-13.
//

import Foundation
import Darwin

struct SystemMonitorCPUCounters: Equatable, Sendable {
    let user: UInt64
    let system: UInt64
    let idle: UInt64
    let nice: UInt64

    var total: UInt64 {
        user + system + idle + nice
    }

    func usagePercent(since previous: SystemMonitorCPUCounters?) -> Double {
        guard let previous else {
            let lifetimeTotal = max(total, 1)
            return percent(nonIdle: user + system + nice, total: lifetimeTotal)
        }

        let deltaUser = user &- previous.user
        let deltaSystem = system &- previous.system
        let deltaIdle = idle &- previous.idle
        let deltaNice = nice &- previous.nice
        let deltaTotal = max(deltaUser + deltaSystem + deltaIdle + deltaNice, 1)

        return percent(nonIdle: deltaUser + deltaSystem + deltaNice, total: deltaTotal)
    }
}

struct SystemMonitorMemorySample: Equatable, Sendable {
    let usedBytes: UInt64
    let totalBytes: UInt64

    var percentUsed: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes) * 100
    }
}

struct SystemMonitorDiskSample: Equatable, Sendable {
    let usedBytes: Int64
    let totalBytes: Int64

    var percentUsed: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes) * 100
    }
}

struct SystemMonitorSnapshot: Equatable, Sendable {
    let cpuPercent: Double
    let memoryPercent: Double
    let diskPercent: Double?
    let uptimeText: String
    let loadAverageText: String

    var cpuDisplay: String {
        SystemMonitorFormatting.percentString(cpuPercent)
    }

    var memoryDisplay: String {
        SystemMonitorFormatting.percentString(memoryPercent)
    }

    var diskDisplay: String? {
        diskPercent.map(SystemMonitorFormatting.percentString)
    }

    var widgetValue: WidgetValue {
        var payload: [String: WidgetValue] = [
            "cpu": .object([
                "percent": .double(cpuPercent),
                "display": .string(SystemMonitorFormatting.percentString(cpuPercent)),
            ]),
            "memory": .object([
                "percent": .double(memoryPercent),
                "display": .string(SystemMonitorFormatting.percentString(memoryPercent)),
            ]),
            "uptime": .string(uptimeText),
            "loadAverage": .string(loadAverageText),
        ]

        if let diskPercent {
            payload["disk"] = .object([
                "percent": .double(diskPercent),
                "display": .string(SystemMonitorFormatting.percentString(diskPercent)),
            ])
        }

        return .object(payload)
    }

    init(
        cpuPercent: Double,
        memoryPercent: Double,
        diskPercent: Double?,
        uptimeText: String,
        loadAverageText: String
    ) {
        self.cpuPercent = cpuPercent
        self.memoryPercent = memoryPercent
        self.diskPercent = diskPercent
        self.uptimeText = uptimeText
        self.loadAverageText = loadAverageText
    }

    init?(widgetValue: WidgetValue?) {
        guard case .object(let root)? = widgetValue else { return nil }
        guard
            let cpu = Self.percent(for: "cpu", in: root),
            let memory = Self.percent(for: "memory", in: root),
            case .string(let uptime)? = root["uptime"],
            case .string(let loadAverage)? = root["loadAverage"]
        else {
            return nil
        }

        self.cpuPercent = cpu
        self.memoryPercent = memory
        self.diskPercent = Self.percent(for: "disk", in: root)
        self.uptimeText = uptime
        self.loadAverageText = loadAverage
    }

    private static func percent(for key: String, in root: [String: WidgetValue]) -> Double? {
        guard case .object(let object)? = root[key] else { return nil }

        switch object["percent"] {
        case .double(let value):
            return value
        case .integer(let value):
            return Double(value)
        default:
            return nil
        }
    }
}

enum SystemMonitorFormatting {
    static func percentString(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    static func uptimeString(from seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = seconds >= 86_400 ? [.day, .hour, .minute] : [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 3
        formatter.zeroFormattingBehavior = .dropAll
        return formatter.string(from: seconds) ?? "0m"
    }

    static func loadAverageString(_ values: [Double]) -> String {
        values.map { String(format: "%.2f", $0) }.joined(separator: " ")
    }
}

actor SystemMonitorProvider: FrameworkDataProviding {
    static let api = "system-monitor"

    let api: String = SystemMonitorProvider.api

    private var previousCPUSample: SystemMonitorCPUCounters?

    func fetch() async throws -> WidgetValue {
        let cpuCounters = try readCPUCounters()
        let memory = try readMemorySample()
        let disk = readDiskSample()
        let cpuPercent = min(max(cpuCounters.usagePercent(since: previousCPUSample), 0), 100)
        previousCPUSample = cpuCounters

        let snapshot = SystemMonitorSnapshot(
            cpuPercent: cpuPercent,
            memoryPercent: min(max(memory.percentUsed, 0), 100),
            diskPercent: disk.map { min(max($0.percentUsed, 0), 100) },
            uptimeText: SystemMonitorFormatting.uptimeString(from: ProcessInfo.processInfo.systemUptime),
            loadAverageText: SystemMonitorFormatting.loadAverageString(readLoadAverages())
        )

        return snapshot.widgetValue
    }

    private func readCPUCounters() throws -> SystemMonitorCPUCounters {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { integerPointer in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, integerPointer, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            throw ChannelExecutorError.frameworkEncodingFailed("CPU counters unavailable.")
        }

        return SystemMonitorCPUCounters(
            user: UInt64(info.cpu_ticks.0),
            system: UInt64(info.cpu_ticks.1),
            idle: UInt64(info.cpu_ticks.2),
            nice: UInt64(info.cpu_ticks.3)
        )
    }

    private func readMemorySample() throws -> SystemMonitorMemorySample {
        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { integerPointer in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, integerPointer, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            throw ChannelExecutorError.frameworkEncodingFailed("Memory statistics unavailable.")
        }

        let usedPages = UInt64(stats.active_count + stats.wire_count + stats.compressor_page_count)
        let usedBytes = usedPages * UInt64(pageSize)

        return SystemMonitorMemorySample(
            usedBytes: usedBytes,
            totalBytes: ProcessInfo.processInfo.physicalMemory
        )
    }

    private func readDiskSample() -> SystemMonitorDiskSample? {
        let rootURL = URL(fileURLWithPath: "/")
        let keys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey,
        ]

        guard let values = try? rootURL.resourceValues(forKeys: keys),
              let total = values.volumeTotalCapacity else {
            return nil
        }

        let available = Int64(
            values.volumeAvailableCapacityForImportantUsage
                ?? Int64(values.volumeAvailableCapacity ?? 0)
        )

        return SystemMonitorDiskSample(
            usedBytes: Int64(total) - available,
            totalBytes: Int64(total)
        )
    }

    private func readLoadAverages() -> [Double] {
        var loads = [Double](repeating: 0, count: 3)
        guard getloadavg(&loads, 3) == 3 else {
            return [0, 0, 0]
        }
        return loads
    }
}

private func percent(nonIdle: UInt64, total: UInt64) -> Double {
    guard total > 0 else { return 0 }
    return Double(nonIdle) / Double(total) * 100
}
