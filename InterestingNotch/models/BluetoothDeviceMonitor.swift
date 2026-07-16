//
//  BluetoothDeviceMonitor.swift
//  InterestingNotch
//

import Defaults
import CoreAudio
import Foundation
@preconcurrency import IOBluetooth
import IOKit.audio

struct BluetoothDeviceSnapshot: Identifiable, Equatable, Sendable {
    let address: String
    let name: String
    let isConnected: Bool

    var id: String { address }

    var symbolName: String {
        let lowercasedName = name.lowercased()
        if lowercasedName.contains("airpod") { return "airpodspro" }
        if lowercasedName.contains("headphone") || lowercasedName.contains("buds") {
            return "headphones"
        }
        if lowercasedName.contains("keyboard") { return "keyboard" }
        if lowercasedName.contains("mouse") || lowercasedName.contains("trackpad") {
            return "computermouse"
        }
        if lowercasedName.contains("controller") || lowercasedName.contains("gamepad") {
            return "gamecontroller"
        }
        return "dot.radiowaves.left.and.right"
    }
}

struct BluetoothConnectionEvent: Identifiable, Equatable {
    let id = UUID()
    let device: BluetoothDeviceSnapshot
    let isConnected: Bool
}

@MainActor
final class BluetoothDeviceMonitor: NSObject, ObservableObject {
    static let shared = BluetoothDeviceMonitor()

    @Published private(set) var devices: [BluetoothDeviceSnapshot] = []
    @Published private(set) var currentEvent: BluetoothConnectionEvent?
    @Published private(set) var isMonitoring = false

    private var connectNotification: IOBluetoothUserNotification?
    private var disconnectNotifications: [String: IOBluetoothUserNotification] = [:]
    private var dismissTask: Task<Void, Never>?
    private var audioListenersInstalled = false
    private var audioRefreshWorkItem: DispatchWorkItem?
    private var lastReportedConnectionStates: [String: Bool] = [:]
    private var callbackStateSuppressions: [String: (state: Bool, expiresAt: Date)] = [:]
    private let inventoryQueue = DispatchQueue(
        label: "com.nodescraper.interestingnotch.bluetooth-inventory",
        qos: .userInitiated
    )

    override private init() {
        super.init()
    }

    func enable() {
        guard !isMonitoring else {
            registerConnectNotificationIfNeeded()
            refreshDevices()
            return
        }

        // Seed connection state before registering callbacks. IOBluetooth can
        // synchronously replay already-connected devices during registration;
        // without this baseline, a genuine connection in the startup window
        // is indistinguishable from that replay and gets dropped.
        let pairedDevices = Self.pairedDevices()
        let snapshots = Self.uniqueSnapshots(from: pairedDevices)
        devices = snapshots
        lastReportedConnectionStates = snapshots.reduce(into: [:]) { states, snapshot in
            states[Self.normalizedAddress(snapshot.address)] = snapshot.isConnected
        }

        isMonitoring = true
        installAudioListenersIfNeeded()
        registerDisconnectNotifications(for: pairedDevices)
        registerConnectNotificationIfNeeded()
        refreshDevices()
    }

    func applyDefaultNotificationPreferences() {
        let pairedDevices = Self.pairedDevices()
        let addresses = Self.uniqueSnapshots(from: pairedDevices)
            .map(\.address)
            .map(Self.normalizedAddress)

        Defaults[.bluetoothNotificationsEnabled] = true
        Defaults[.bluetoothConnectedNotifications] = true
        Defaults[.bluetoothDisconnectedNotifications] = true
        Defaults[.bluetoothNotificationDeviceAddresses] = addresses

        if isMonitoring {
            registerDisconnectNotifications(for: pairedDevices)
            refreshDevices()
        }
    }

    private func registerConnectNotificationIfNeeded() {
        guard connectNotification == nil else { return }
        connectNotification = IOBluetoothDevice.register(
            forConnectNotifications: self,
            selector: #selector(deviceConnected(_:device:))
        )
    }

    func disable() {
        connectNotification?.unregister()
        connectNotification = nil
        disconnectNotifications.values.forEach { $0.unregister() }
        disconnectNotifications.removeAll()
        dismissTask?.cancel()
        audioRefreshWorkItem?.cancel()
        currentEvent = nil
        lastReportedConnectionStates.removeAll()
        callbackStateSuppressions.removeAll()
        isMonitoring = false
        refreshDevices()
    }

    func refreshDevices() {
        inventoryQueue.async { [weak self] in
            let pairedDevices = Self.pairedDevices()
            let snapshots = Self.uniqueSnapshots(from: pairedDevices)

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.devices = snapshots
                if self.isMonitoring {
                    self.registerDisconnectNotifications(for: pairedDevices)
                    self.reportConnectionChanges(in: snapshots)
                }
            }
        }
    }

    private func installAudioListenersIfNeeded() {
        guard !audioListenersInstalled else { return }
        audioListenersInstalled = true

        var defaultOutputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultOutputAddress,
            DispatchQueue.main
        ) { [weak self] _, _ in
            self?.scheduleAudioRefresh()
        }

        var devicesAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &devicesAddress,
            DispatchQueue.main
        ) { [weak self] _, _ in
            self?.scheduleAudioRefresh()
        }
    }

    private func scheduleAudioRefresh() {
        guard isMonitoring else { return }
        audioRefreshWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.refreshDevices()
        }
        audioRefreshWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: workItem)
    }

    private func reportConnectionChanges(in snapshots: [BluetoothDeviceSnapshot]) {
        let now = Date()
        callbackStateSuppressions = callbackStateSuppressions.filter { $0.value.expiresAt > now }

        let currentStates = snapshots.reduce(into: [String: Bool]()) { states, snapshot in
            states[Self.normalizedAddress(snapshot.address)] = snapshot.isConnected
        }

        var statesToReport = currentStates

        for snapshot in snapshots {
            let address = Self.normalizedAddress(snapshot.address)

            // IOBluetooth may briefly return the pre-callback state while the
            // device teardown/connection settles. Do not turn one real
            // disconnect into a false Connected -> Disconnected sequence.
            if let suppression = callbackStateSuppressions[address],
               snapshot.isConnected != suppression.state
            {
                statesToReport[address] = suppression.state
                continue
            }

            guard let previousState = lastReportedConnectionStates[address],
                  previousState != snapshot.isConnected
            else { continue }
            showEvent(for: snapshot, connected: snapshot.isConnected)
        }

        lastReportedConnectionStates = statesToReport
    }

    func preview(device: BluetoothDeviceSnapshot, connected: Bool) {
        showEvent(for: device, connected: connected, ignoresPreferences: true)
    }

    private func registerDisconnectNotifications(for devices: [IOBluetoothDevice]) {
        let selectedAddresses = Set(
            Defaults[.bluetoothNotificationDeviceAddresses].map(Self.normalizedAddress)
        )

        for address in Array(disconnectNotifications.keys) where !selectedAddresses.contains(address) {
            disconnectNotifications.removeValue(forKey: address)?.unregister()
        }

        for device in devices {
            guard let rawAddress = device.addressString else { continue }
            let address = Self.normalizedAddress(rawAddress)
            guard selectedAddresses.contains(address),
                  disconnectNotifications[address] == nil
            else {
                continue
            }
            disconnectNotifications[address] = device.register(
                forDisconnectNotification: self,
                selector: #selector(deviceDisconnected(_:device:))
            )
        }
    }

    // IOBluetooth invokes these selectors on its own coordinator queue and can
    // synchronously replay already-connected devices while registration is in
    // progress. Never publish SwiftUI state from inside that callback: doing so
    // can deadlock the main thread's observation graph during app startup.
    @objc nonisolated private func deviceConnected(
        _ notification: IOBluetoothUserNotification,
        device: IOBluetoothDevice
    ) {
        guard let snapshot = Self.snapshot(for: device) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.handleDeviceConnected(snapshot)
        }
    }

    @objc nonisolated private func deviceDisconnected(
        _ notification: IOBluetoothUserNotification,
        device: IOBluetoothDevice
    ) {
        guard let snapshot = Self.snapshot(for: device, connected: false) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.handleDeviceDisconnected(snapshot)
        }
    }

    private func handleDeviceConnected(_ snapshot: BluetoothDeviceSnapshot) {
        let address = Self.normalizedAddress(snapshot.address)
        let previousState = lastReportedConnectionStates[address]
        lastReportedConnectionStates[address] = true
        callbackStateSuppressions[address] = (state: true, expiresAt: Date().addingTimeInterval(0.75))
        scheduleAudioRefresh()

        // The baseline is seeded before registration, so nil now means a newly
        // discovered device rather than a registration replay.
        guard previousState != true else { return }
        showEvent(for: snapshot, connected: true)
    }

    private func handleDeviceDisconnected(_ snapshot: BluetoothDeviceSnapshot) {
        let address = Self.normalizedAddress(snapshot.address)
        let previousState = lastReportedConnectionStates[address]
        lastReportedConnectionStates[address] = false
        callbackStateSuppressions[address] = (state: false, expiresAt: Date().addingTimeInterval(0.75))
        disconnectNotifications.removeValue(forKey: address)?.unregister()
        scheduleAudioRefresh()

        guard previousState == true else { return }
        showEvent(for: snapshot, connected: false)
    }

    private func showEvent(
        for device: BluetoothDeviceSnapshot,
        connected: Bool,
        ignoresPreferences: Bool = false
    ) {
        if !ignoresPreferences {
            guard Defaults[.bluetoothNotificationsEnabled] else { return }
            let selectedAddresses = Defaults[.bluetoothNotificationDeviceAddresses]
                .map(Self.normalizedAddress)
            guard selectedAddresses.contains(Self.normalizedAddress(device.address)) else { return }
            guard connected
                ? Defaults[.bluetoothConnectedNotifications]
                : Defaults[.bluetoothDisconnectedNotifications]
            else { return }

            // Keep callback-driven and CoreAudio-driven detection from showing
            // the same transition twice while the inventory refresh catches up.
            lastReportedConnectionStates[Self.normalizedAddress(device.address)] = connected
        }

        let event = BluetoothConnectionEvent(device: device, isConnected: connected)
        currentEvent = event
        dismissTask?.cancel()
        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(max(1, Defaults[.bluetoothNotificationDuration])))
            guard !Task.isCancelled, currentEvent?.id == event.id else { return }
            currentEvent = nil
        }
    }

    nonisolated private static func snapshot(
        for device: IOBluetoothDevice,
        connected: Bool? = nil
    ) -> BluetoothDeviceSnapshot? {
        guard let address = device.addressString else { return nil }
        let name = device.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        return BluetoothDeviceSnapshot(
            address: address,
            name: name?.isEmpty == false ? name! : "Bluetooth Device",
            isConnected: connected ?? device.isConnected()
        )
    }

    nonisolated private static func pairedDevices() -> [IOBluetoothDevice] {
        (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
    }

    nonisolated private static func uniqueSnapshots(
        from devices: [IOBluetoothDevice]
    ) -> [BluetoothDeviceSnapshot] {
        let snapshotsByAddress = devices
            .compactMap { snapshot(for: $0) }
            .reduce(into: [String: BluetoothDeviceSnapshot]()) { snapshots, snapshot in
                snapshots[normalizedAddress(snapshot.address)] = snapshot
            }
        return snapshotsByAddress.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    nonisolated private static func normalizedAddress(_ address: String) -> String {
        address.uppercased()
    }
}
