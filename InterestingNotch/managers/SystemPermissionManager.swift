//
//  SystemPermissionManager.swift
//  InterestingNotch
//

import AppKit
import AVFoundation
import CoreBluetooth
import EventKit

enum SystemSettingsDestination: CaseIterable {
    case camera
    case microphone
    case calendars
    case reminders
    case bluetooth
    case accessibility
    case screenRecording

    var candidateURLStrings: [String] {
        switch self {
        case .camera:
            return ["x-apple.systempreferences:com.apple.preference.security?Privacy_Camera"]
        case .microphone:
            return ["x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"]
        case .calendars:
            return ["x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"]
        case .reminders:
            return ["x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders"]
        case .bluetooth:
            return [
                "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth",
                "x-apple.systempreferences:com.apple.BluetoothSettings",
            ]
        case .accessibility:
            return ["x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"]
        case .screenRecording:
            return ["x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"]
        }
    }
}

@MainActor
final class SystemPermissionManager: NSObject, CBCentralManagerDelegate {
    static let shared = SystemPermissionManager()

    private let eventStore = EKEventStore()
    private var bluetoothManager: CBCentralManager?
    private var bluetoothWaiters: [CheckedContinuation<Bool, Never>] = []

    private override init() {
        super.init()
    }

    func requestCameraAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    func requestMicrophoneAccess() async -> Bool {
        if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized {
            return true
        }

        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .audio)
        }

        // AVAudioRecorder and AVCaptureDevice share macOS's Microphone TCC
        // decision. Read the canonical capture-device status after prompting.
        return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    func requestCalendarAccess() async -> Bool {
        (try? await eventStore.requestFullAccessToEvents()) ?? false
    }

    func requestRemindersAccess() async -> Bool {
        (try? await eventStore.requestFullAccessToReminders()) ?? false
    }

    func requestBluetoothAccess() async -> Bool {
        switch CBManager.authorization {
        case .allowedAlways:
            BluetoothDeviceMonitor.shared.enable()
            BluetoothDeviceMonitor.shared.applyDefaultNotificationPreferences()
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            break
        @unknown default:
            return false
        }

        if bluetoothManager == nil {
            // Constructing a CoreBluetooth manager is the supported way to
            // trigger macOS's Bluetooth privacy prompt. Retain it until the
            // delegate callback so the request is owned by InterestingNotch.
            bluetoothManager = CBCentralManager(
                delegate: self,
                queue: .main,
                options: [CBCentralManagerOptionShowPowerAlertKey: false]
            )
        }

        return await withCheckedContinuation { continuation in
            bluetoothWaiters.append(continuation)
            if CBManager.authorization != .notDetermined {
                finishBluetoothRequest()
            }
        }
    }

    func requestAccessibilityAccess() async -> Bool {
        await XPCHelperClient.shared.ensureAccessibilityAuthorization(promptIfNeeded: true)
    }

    func openSettings(_ destination: SystemSettingsDestination) {
        for candidate in destination.candidateURLStrings {
            guard let url = URL(string: candidate) else { continue }
            if NSWorkspace.shared.open(url) {
                return
            }
        }

        NSWorkspace.shared.openApplication(
            at: URL(fileURLWithPath: "/System/Applications/System Settings.app"),
            configuration: NSWorkspace.OpenConfiguration()
        ) { _, _ in }
    }

    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            finishBluetoothRequest()
        }
    }

    private func finishBluetoothRequest() {
        guard CBManager.authorization != .notDetermined else { return }
        let granted = CBManager.authorization == .allowedAlways
        let waiters = bluetoothWaiters
        bluetoothWaiters.removeAll()
        waiters.forEach { $0.resume(returning: granted) }

        if granted {
            BluetoothDeviceMonitor.shared.enable()
            BluetoothDeviceMonitor.shared.applyDefaultNotificationPreferences()
        }
    }
}
