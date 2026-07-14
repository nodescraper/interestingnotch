//
//  NetworkMonitorProvider.swift
//  InterestingNotch
//
//  Created by Codex on 2026-07-14.
//  Mirrors SystemMonitorProvider: an actor that samples real interface byte
//  counters and serializes a snapshot to WidgetValue.
//

import Foundation
import Darwin

// MARK: - Raw counters

struct NetworkMonitorCounters: Equatable, Sendable {
    let receivedBytes: UInt64
    let sentBytes: UInt64
    /// Monotonic timestamp of the sample, used to compute per-second rates.
    let timestamp: TimeInterval

    /// Bytes-per-second since the previous sample. First sample yields zeros.
    func rates(since previous: NetworkMonitorCounters?) -> (down: Double, up: Double) {
        guard let previous else { return (0, 0) }
        let dt = max(timestamp - previous.timestamp, 0.001)
        // &- guards against counter wraparound / interface reset.
        let dDown = Double(receivedBytes &- previous.receivedBytes)
        let dUp = Double(sentBytes &- previous.sentBytes)
        return (max(dDown, 0) / dt, max(dUp, 0) / dt)
    }
}

// MARK: - Snapshot

struct NetworkMonitorSnapshot: Equatable, Sendable {
    /// Bytes per second.
    let downloadBytesPerSec: Double
    let uploadBytesPerSec: Double
    /// Cumulative bytes since the app started sampling.
    let totalReceivedBytes: UInt64
    let totalSentBytes: UInt64
    /// Rolling peak (bytes/sec) used to scale the rings, so a quiet link still
    /// shows relative activity and a busy link doesn't peg at 100%.
    let peakBytesPerSec: Double

    var downloadDisplay: String { NetworkMonitorFormatting.rateString(downloadBytesPerSec) }
    var uploadDisplay: String { NetworkMonitorFormatting.rateString(uploadBytesPerSec) }
    var totalReceivedDisplay: String { NetworkMonitorFormatting.byteString(totalReceivedBytes) }
    var totalSentDisplay: String { NetworkMonitorFormatting.byteString(totalSentBytes) }

    var widgetValue: WidgetValue {
        .object([
            "download": .object([
                "bytesPerSec": .double(downloadBytesPerSec),
                "display": .string(downloadDisplay),
            ]),
            "upload": .object([
                "bytesPerSec": .double(uploadBytesPerSec),
                "display": .string(uploadDisplay),
            ]),
            "totalReceived": .object([
                "bytes": .double(Double(totalReceivedBytes)),
                "display": .string(totalReceivedDisplay),
            ]),
            "totalSent": .object([
                "bytes": .double(Double(totalSentBytes)),
                "display": .string(totalSentDisplay),
            ]),
            "peakBytesPerSec": .double(peakBytesPerSec),
        ])
    }

    init(
        downloadBytesPerSec: Double,
        uploadBytesPerSec: Double,
        totalReceivedBytes: UInt64,
        totalSentBytes: UInt64,
        peakBytesPerSec: Double
    ) {
        self.downloadBytesPerSec = downloadBytesPerSec
        self.uploadBytesPerSec = uploadBytesPerSec
        self.totalReceivedBytes = totalReceivedBytes
        self.totalSentBytes = totalSentBytes
        self.peakBytesPerSec = peakBytesPerSec
    }

    init?(widgetValue: WidgetValue?) {
        guard case .object(let root)? = widgetValue else { return nil }
        guard
            let down = Self.double(for: "download", key: "bytesPerSec", in: root),
            let up = Self.double(for: "upload", key: "bytesPerSec", in: root)
        else { return nil }

        self.downloadBytesPerSec = down
        self.uploadBytesPerSec = up
        self.totalReceivedBytes = UInt64(max(Self.double(for: "totalReceived", key: "bytes", in: root) ?? 0, 0))
        self.totalSentBytes = UInt64(max(Self.double(for: "totalSent", key: "bytes", in: root) ?? 0, 0))
        if case .double(let peak)? = root["peakBytesPerSec"] {
            self.peakBytesPerSec = peak
        } else {
            self.peakBytesPerSec = max(down, up, 1)
        }
    }

    private static func double(for parent: String, key: String, in root: [String: WidgetValue]) -> Double? {
        guard case .object(let object)? = root[parent] else { return nil }
        switch object[key] {
        case .double(let value): return value
        case .integer(let value): return Double(value)
        default: return nil
        }
    }
}

// MARK: - Formatting

enum NetworkMonitorFormatting {
    /// Human speed, e.g. "1.2 MB/s", "840 KB/s", "0 B/s".
    static func rateString(_ bytesPerSec: Double) -> String {
        byteString(UInt64(max(bytesPerSec, 0))) + "/s"
    }

    /// Human byte size, e.g. "3.4 GB", "512 MB".
    static func byteString(_ bytes: UInt64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var unit = 0
        while value >= 1024 && unit < units.count - 1 {
            value /= 1024
            unit += 1
        }
        if unit == 0 {
            return "\(Int(value)) \(units[unit])"
        }
        return String(format: "%.1f %@", value, units[unit])
    }
}

// MARK: - Provider

actor NetworkMonitorProvider: FrameworkDataProviding {
    static let api = "network-monitor"
    let api: String = NetworkMonitorProvider.api

    private var previous: NetworkMonitorCounters?
    private var rollingPeak: Double = 1          // bytes/sec, decays over time
    private let peakDecay: Double = 0.9          // multiply each sample so peak drifts down

    func fetch() async throws -> WidgetValue {
        let counters = try readCounters()
        let (down, up) = counters.rates(since: previous)
        previous = counters

        // Update rolling peak: decay, then raise to current activity.
        rollingPeak = max(rollingPeak * peakDecay, max(down, up), 1)

        let snapshot = NetworkMonitorSnapshot(
            downloadBytesPerSec: down,
            uploadBytesPerSec: up,
            totalReceivedBytes: counters.receivedBytes,
            totalSentBytes: counters.sentBytes,
            peakBytesPerSec: rollingPeak
        )
        return snapshot.widgetValue
    }

    /// Sums received/sent bytes across all active, non-loopback interfaces via getifaddrs.
    private func readCounters() throws -> NetworkMonitorCounters {
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let first = ifaddrPtr else {
            throw ChannelExecutorError.frameworkEncodingFailed("Network interfaces unavailable.")
        }
        defer { freeifaddrs(ifaddrPtr) }

        var totalReceived: UInt64 = 0
        var totalSent: UInt64 = 0

        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let current = ptr {
            defer { ptr = current.pointee.ifa_next }

            let flags = Int32(current.pointee.ifa_flags)
            // Only up, running, non-loopback interfaces.
            guard (flags & IFF_UP) == IFF_UP,
                  (flags & IFF_RUNNING) == IFF_RUNNING,
                  (flags & IFF_LOOPBACK) == 0 else { continue }

            // Link-layer entries carry the byte counters.
            guard let addr = current.pointee.ifa_addr,
                  addr.pointee.sa_family == UInt8(AF_LINK),
                  let dataPtr = current.pointee.ifa_data else { continue }

            let networkData = dataPtr.assumingMemoryBound(to: if_data.self)
            totalReceived += UInt64(networkData.pointee.ifi_ibytes)
            totalSent += UInt64(networkData.pointee.ifi_obytes)
        }

        return NetworkMonitorCounters(
            receivedBytes: totalReceived,
            sentBytes: totalSent,
            timestamp: ProcessInfo.processInfo.systemUptime
        )
    }
}
