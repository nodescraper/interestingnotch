import KeyboardShortcuts
import SwiftUI

struct CaffeineSettings: View {
    @ObservedObject private var caffeineManager = CaffeineManager.shared
    @AppStorage("caffeineEnabled") private var caffeineEnabled = true
    @AppStorage("caffeineDefaultDuration") private var defaultDuration = 3600.0
    @AppStorage("caffeineDefaultMode") private var defaultModeRawValue = CaffeineManager.Mode.displayAwake.rawValue

    private var defaultModeBinding: Binding<CaffeineManager.Mode> {
        Binding(
            get: { CaffeineManager.Mode(rawValue: defaultModeRawValue) ?? .displayAwake },
            set: { defaultModeRawValue = $0.rawValue }
        )
    }

    var body: some View {
        Form {
            Section(header: Text("General")) {
                Toggle("Enable Caffeine header control", isOn: $caffeineEnabled)
                    .onChange(of: caffeineEnabled) {
                        if !caffeineEnabled {
                            caffeineManager.deactivate()
                        }
                    }

                Picker("Mode", selection: defaultModeBinding) {
                    Text("Display awake")
                        .tag(CaffeineManager.Mode.displayAwake)
                    Text("System awake")
                        .tag(CaffeineManager.Mode.systemAwake)
                }
                .pickerStyle(.segmented)
                .disabled(caffeineManager.isActive)

                Picker("Default duration", selection: $defaultDuration) {
                    Text("15m").tag(900.0)
                    Text("1h").tag(3600.0)
                    Text("2h").tag(7200.0)
                    Text("Until off").tag(0.0)
                }
                .pickerStyle(.segmented)
            }

            Section(header: Text("Usage")) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.title2)
                        .foregroundStyle(Color.effectiveAccent)
                    Text("Tap the cup in the open-notch header to toggle Caffeine. Hold it to choose a duration.")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section(header: Text("Shortcut")) {
                KeyboardShortcuts.Recorder("Toggle Caffeine:", name: .caffeineToggle)
            }
        }
        .formStyle(.grouped)
        .accentColor(.effectiveAccent)
        .navigationTitle("Caffeine")
    }
}
