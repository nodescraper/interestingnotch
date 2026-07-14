//
//  SystemMonitorProvider.swift
//  InterestingNotch
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
    let temperatureCelsius: Double?
    let uptimeText: String
    let loadAverageText: String
    /// Combined network throughput (download + upload) in bytes/sec.
    let networkBytesPerSec: Double
    /// Rolling peak used to scale the network ring.
    let networkPeakBytesPerSec: Double

    var cpuDisplay: String {
        SystemMonitorFormatting.percentString(cpuPercent)
    }

    var memoryDisplay: String {
        SystemMonitorFormatting.percentString(memoryPercent)
    }

    var diskDisplay: String? {
        diskPercent.map(SystemMonitorFormatting.percentString)
    }

    var temperatureDisplay: String? {
        temperatureCelsius.map(SystemMonitorFormatting.temperatureString)
    }

    /// Human network rate, e.g. "1.2 MB/s".
    var networkDisplay: String {
        SystemMonitorFormatting.rateString(networkBytesPerSec)
    }

    func displayValue(for metric: SystemMonitorSneakPeekMetric) -> String {
        switch metric {
        case .none:
            return "--%"
        case .cpu:
            return cpuDisplay
        case .memory:
            return memoryDisplay
        case .disk:
            return diskDisplay ?? "--%"
        case .temperature:
            return temperatureDisplay ?? "--°"
        }
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
            "network": .object([
                "bytesPerSec": .double(networkBytesPerSec),
                "peakBytesPerSec": .double(networkPeakBytesPerSec),
                "display": .string(networkDisplay),
            ]),
        ]

        if let diskPercent {
            payload["disk"] = .object([
                "percent": .double(diskPercent),
                "display": .string(SystemMonitorFormatting.percentString(diskPercent)),
            ])
        }

        if let temperatureCelsius {
            payload["temperature"] = .object([
                "celsius": .double(temperatureCelsius),
                "display": .string(SystemMonitorFormatting.temperatureString(temperatureCelsius)),
            ])
        }

        return .object(payload)
    }

    init(
        cpuPercent: Double,
        memoryPercent: Double,
        diskPercent: Double?,
        temperatureCelsius: Double? = nil,
        uptimeText: String,
        loadAverageText: String,
        networkBytesPerSec: Double = 0,
        networkPeakBytesPerSec: Double = 1
    ) {
        self.cpuPercent = cpuPercent
        self.memoryPercent = memoryPercent
        self.diskPercent = diskPercent
        self.temperatureCelsius = temperatureCelsius
        self.uptimeText = uptimeText
        self.loadAverageText = loadAverageText
        self.networkBytesPerSec = networkBytesPerSec
        self.networkPeakBytesPerSec = networkPeakBytesPerSec
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
        self.temperatureCelsius = Self.temperature(in: root)
        self.uptimeText = uptime
        self.loadAverageText = loadAverage

        if case .object(let net)? = root["network"] {
            self.networkBytesPerSec = Self.double(net["bytesPerSec"]) ?? 0
            self.networkPeakBytesPerSec = Self.double(net["peakBytesPerSec"]) ?? 1
        } else {
            self.networkBytesPerSec = 0
            self.networkPeakBytesPerSec = 1
        }
    }

    private static func double(_ value: WidgetValue?) -> Double? {
        switch value {
        case .double(let v): return v
        case .integer(let v): return Double(v)
        default: return nil
        }
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

    private static func temperature(in root: [String: WidgetValue]) -> Double? {
        guard case .object(let object)? = root["temperature"] else { return nil }

        switch object["celsius"] {
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

    static func temperatureString(_ value: Double) -> String {
        "\(Int(value.rounded()))°"
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

    /// Human speed, e.g. "1.2 MB/s".
    static func rateString(_ bytesPerSec: Double) -> String {
        byteString(UInt64(max(bytesPerSec, 0))) + "/s"
    }

    /// Human byte size, e.g. "3.4 GB".
    static func byteString(_ bytes: UInt64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var unit = 0
        while value >= 1024 && unit < units.count - 1 {
            value /= 1024
            unit += 1
        }
        if unit == 0 { return "\(Int(value)) \(units[unit])" }
        return String(format: "%.1f %@", value, units[unit])
    }
}

actor SystemMonitorProvider: FrameworkDataProviding {
    static let api = "system-monitor"

    let api: String = SystemMonitorProvider.api

    private var previousCPUSample: SystemMonitorCPUCounters?

    // Network sampling state.
    private var previousNetSample: (received: UInt64, sent: UInt64, timestamp: TimeInterval)?
    private var networkRollingPeak: Double = 1
    private let networkPeakDecay: Double = 0.9

    func fetch() async throws -> WidgetValue {
        let cpuCounters = try readCPUCounters()
        let memory = try readMemorySample()
        let disk = readDiskSample()
        let cpuPercent = min(max(cpuCounters.usagePercent(since: previousCPUSample), 0), 100)
        previousCPUSample = cpuCounters

        let netRate = readNetworkRate()

        let snapshot = SystemMonitorSnapshot(
            cpuPercent: cpuPercent,
            memoryPercent: min(max(memory.percentUsed, 0), 100),
            diskPercent: disk.map { min(max($0.percentUsed, 0), 100) },
            temperatureCelsius: readTemperatureCelsius(),
            uptimeText: SystemMonitorFormatting.uptimeString(from: ProcessInfo.processInfo.systemUptime),
            loadAverageText: SystemMonitorFormatting.loadAverageString(readLoadAverages()),
            networkBytesPerSec: netRate,
            networkPeakBytesPerSec: networkRollingPeak
        )

        return snapshot.widgetValue
    }

    /// Combined down+up bytes/sec across active non-loopback interfaces, plus
    /// updates the rolling peak used to scale the ring.
    private func readNetworkRate() -> Double {
        guard let counters = readNetworkCounters() else { return 0 }
        let now = ProcessInfo.processInfo.systemUptime

        defer {
            previousNetSample = (counters.received, counters.sent, now)
        }

        guard let previous = previousNetSample else { return 0 }
        let dt = max(now - previous.timestamp, 0.001)
        let down = Double(counters.received &- previous.received) / dt
        let up = Double(counters.sent &- previous.sent) / dt
        let combined = max(down, 0) + max(up, 0)

        networkRollingPeak = max(networkRollingPeak * networkPeakDecay, combined, 1)
        return combined
    }

    private func readNetworkCounters() -> (received: UInt64, sent: UInt64)? {
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let first = ifaddrPtr else { return nil }
        defer { freeifaddrs(ifaddrPtr) }

        var totalReceived: UInt64 = 0
        var totalSent: UInt64 = 0

        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let current = ptr {
            defer { ptr = current.pointee.ifa_next }
            let flags = Int32(current.pointee.ifa_flags)
            guard (flags & IFF_UP) == IFF_UP,
                  (flags & IFF_RUNNING) == IFF_RUNNING,
                  (flags & IFF_LOOPBACK) == 0 else { continue }
            guard let addr = current.pointee.ifa_addr,
                  addr.pointee.sa_family == UInt8(AF_LINK),
                  let dataPtr = current.pointee.ifa_data else { continue }
            let networkData = dataPtr.assumingMemoryBound(to: if_data.self)
            totalReceived += UInt64(networkData.pointee.ifi_ibytes)
            totalSent += UInt64(networkData.pointee.ifi_obytes)
        }

        return (totalReceived, totalSent)
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

    private func readTemperatureCelsius() -> Double? {
        var cpuInfo: processor_info_array_t?
        var cpuCount: natural_t = 0
        var infoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            processor_flavor_t(PROCESSOR_TEMPERATURE),
            &cpuCount,
            &cpuInfo,
            &infoCount
        )

        guard result == KERN_SUCCESS,
              let cpuInfo,
              infoCount > 0 else {
            return nil
        }

        defer {
            let size = vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.size)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), size)
        }

        let samples = UnsafeBufferPointer(start: cpuInfo, count: Int(infoCount)).map(Double.init)
        guard !samples.isEmpty else { return nil }

        let maxSample = samples.max() ?? 0
        let normalizedSample: Double

        if maxSample > 1_000 {
            normalizedSample = maxSample / 100.0
        } else if maxSample > 200 {
            normalizedSample = maxSample / 10.0
        } else {
            normalizedSample = maxSample
        }

        guard normalizedSample.isFinite, normalizedSample > 0 else {
            return nil
        }

        return normalizedSample
    }
}

private func percent(nonIdle: UInt64, total: UInt64) -> Double {
    guard total > 0 else { return 0 }
    return Double(nonIdle) / Double(total) * 100
}
