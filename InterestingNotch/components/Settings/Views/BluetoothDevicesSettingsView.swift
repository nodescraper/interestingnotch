//
//  BluetoothDevicesSettingsView.swift
//  InterestingNotch
//

import Defaults
import SwiftUI

struct BluetoothDevicesSettingsView: View {
    @ObservedObject private var monitor = BluetoothDeviceMonitor.shared
    @Default(.bluetoothNotificationsEnabled) private var notificationsEnabled
    @Default(.bluetoothNotificationDeviceAddresses) private var selectedAddresses
    @Default(.bluetoothConnectedNotifications) private var showConnected
    @Default(.bluetoothDisconnectedNotifications) private var showDisconnected
    @Default(.bluetoothNotificationDuration) private var duration

    var body: some View {
        Form {
            Section {
                Toggle("Bluetooth connection notifications", isOn: $notificationsEnabled)
            } header: {
                Text("Bluetooth Devices")
            } footer: {
                Text("InterestingNotch listens for Bluetooth connection changes and does not poll in the background.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            Section {
                if monitor.devices.isEmpty {
                    ContentUnavailableView(
                        "No Paired Devices",
                        systemImage: "antenna.radiowaves.left.and.right.slash",
                        description: Text("Pair a device in System Settings, then refresh this list.")
                    )
                } else {
                    ForEach(monitor.devices) { device in
                        deviceRow(device)
                    }
                }

                Button("Refresh Devices") {
                    monitor.refreshDevices()
                }
            } header: {
                Text("Notify For")
            } footer: {
                Text("Select the paired devices whose connection changes should appear in the notch.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            Section {
                Toggle("Connected", isOn: $showConnected)
                Toggle("Disconnected", isOn: $showDisconnected)
                Stepper(value: $duration, in: 1...15, step: 1) {
                    LabeledContent("Popup time") {
                        Text("\(Int(duration)) seconds")
                            .monospacedDigit()
                    }
                }
            } header: {
                Text("Notifications")
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Bluetooth Devices")
        .onAppear {
            monitor.refreshDevices()
            syncMonitoring()
        }
            .onChange(of: notificationsEnabled) { _, _ in
                syncMonitoring()
            }
            .onChange(of: selectedAddresses) { _, _ in
                monitor.refreshDevices()
            }
    }

    private func deviceRow(_ device: BluetoothDeviceSnapshot) -> some View {
        HStack(spacing: 12) {
            Toggle(isOn: selectionBinding(for: device.address)) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(device.name)
                        Text(device.isConnected ? "Connected" : "Disconnected")
                            .font(.caption)
                            .foregroundStyle(device.isConnected ? Color.green : Color.secondary)
                    }
                } icon: {
                    Image(systemName: device.symbolName)
                        .frame(width: 20)
                }
            }

            Menu {
                Button("Preview Connected") {
                    monitor.preview(device: device, connected: true)
                }
                Button("Preview Disconnected") {
                    monitor.preview(device: device, connected: false)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    private func selectionBinding(for address: String) -> Binding<Bool> {
        Binding(
            get: { selectedAddresses.contains(address) },
            set: { selected in
                if selected {
                    if !selectedAddresses.contains(address) {
                        selectedAddresses.append(address)
                    }
                } else {
                    selectedAddresses.removeAll { $0 == address }
                }
            }
        )
    }

    private func syncMonitoring() {
        if notificationsEnabled {
            monitor.enable()
        } else {
            monitor.disable()
        }
    }
}
