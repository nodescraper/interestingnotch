import AppKit
import SwiftUI

struct CustomWidgetsSettingsView: View {
    @AppStorage("customWidgetsEnabled") private var enabled = false
    @ObservedObject private var watcher = CustomPeekWatcher.shared
    @ObservedObject private var preferences = CustomPeekPreferences.shared

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $enabled) {
                    HStack(spacing: 8) { Text("Enable custom widgets"); customBadge(text: "Beta") }
                }
                if enabled {
                    LabeledContent("Watched folder") { Text(watcher.folderURL.path).font(.caption.monospaced()).foregroundStyle(.secondary).textSelection(.enabled) }
                    HStack {
                        Circle().fill(watcher.isWatching ? .green : .secondary).frame(width: 7, height: 7)
                        Text(watcher.isWatching ? "Watching for sneak peeks" : "Watcher is off").foregroundStyle(.secondary)
                        Spacer()
                        Button("Reveal") { NSWorkspace.shared.activateFileViewerSelecting([watcher.folderURL]) }
                        Button("Rescan") { watcher.rescan() }
                    }
                }
            } header: { Text("Custom Widgets") } footer: {
                Text("Write one JSON file per sneak peek to ~/.interestingnotch/peeks. The filename becomes its id; remove the file to clear it.").font(.caption).foregroundStyle(.secondary)
            }
            if enabled && !watcher.parseErrors.isEmpty {
                Section("File errors") {
                    ForEach(watcher.parseErrors.keys.sorted(), id: \.self) { id in
                        LabeledContent(id) { Text(watcher.parseErrors[id] ?? "Unknown error").foregroundStyle(.red) }
                    }
                }
            }
            if enabled {
                Section {
                    if watcher.availablePeeks.isEmpty {
                        Text("No valid JSON peek files found.").foregroundStyle(.secondary)
                    } else {
                        ForEach(watcher.availablePeeks) { peek in
                            peekSettingsRow(peek)
                        }
                    }
                } header: {
                    Text("Peek files")
                } footer: {
                    Text("Persistent peeks stay visible until their file is removed or its duration expires. Pop-up peeks hide after the selected time while their file remains available for the next update.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Custom Widgets")
        .onAppear { syncWatcher(enabled) }
        .onChange(of: enabled) { _, value in syncWatcher(value) }
    }

    private func syncWatcher(_ enabled: Bool) { if enabled { watcher.enable() } else { watcher.disable() } }

    private func peekSettingsRow(_ peek: CustomPeek) -> some View {
        let preference = preferences.preference(for: peek.id)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let icon = peek.icon, !icon.isEmpty { Image(systemName: icon).foregroundStyle(peek.accent) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(peek.title).font(.headline)
                    Text(peek.id).font(.caption.monospaced()).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Enabled", isOn: enabledBinding(for: peek.id))
                    .labelsHidden()
            }
            HStack {
                Picker("Display", selection: displayModeBinding(for: peek.id)) {
                    ForEach(CustomPeekDisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                if preference.displayMode == .popUp {
                    Stepper(value: popUpDurationBinding(for: peek.id), in: 1...60, step: 1) {
                        Text("\(Int(preference.popUpDuration)) sec")
                            .monospacedDigit()
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func enabledBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { preferences.preference(for: id).isEnabled },
            set: { newValue in
                var preference = preferences.preference(for: id)
                preference.isEnabled = newValue
                preferences.update(preference, for: id)
            }
        )
    }

    private func displayModeBinding(for id: String) -> Binding<CustomPeekDisplayMode> {
        Binding(
            get: { preferences.preference(for: id).displayMode },
            set: { newValue in
                var preference = preferences.preference(for: id)
                preference.displayMode = newValue
                preferences.update(preference, for: id)
            }
        )
    }

    private func popUpDurationBinding(for id: String) -> Binding<TimeInterval> {
        Binding(
            get: { preferences.preference(for: id).popUpDuration },
            set: { newValue in
                var preference = preferences.preference(for: id)
                preference.popUpDuration = newValue
                preferences.update(preference, for: id)
            }
        )
    }
}
