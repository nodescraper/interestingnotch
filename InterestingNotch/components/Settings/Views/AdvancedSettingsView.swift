//
//  AdvancedSettingsView.swift
//  InterestingNotch
//
//  Created by Richard Kunkli on 07/08/2024.
//

import Defaults
import SwiftUI

struct Advanced: View {
    @Default(.extendHoverArea) var extendHoverArea
    @Default(.showOnLockScreen) var showOnLockScreen
    @Default(.hideFromScreenRecording) var hideFromScreenRecording
    
    let icons: [String] = ["logo2"]
    @State private var selectedIcon: String = "logo2"
    
    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .enableShadow) {
                    Text("Enable window shadow")
                }
                Defaults.Toggle(key: .cornerRadiusScaling) {
                    Text("Scale corner radius for closed notch")
                }
            } header: {
                Text("Window Appearance")
            }

            Section {
                Defaults.Toggle(key: .extendHoverArea) {
                    Text("Extend hover area")
                }
                Defaults.Toggle(key: .hideTitleBar) {
                    Text("Hide title bar")
                }
                Defaults.Toggle(key: .showOnLockScreen) {
                    Text("Show notch on lock screen")
                }
                Defaults.Toggle(key: .hideFromScreenRecording) {
                    Text("Hide from screen recording")
                }
                Defaults.Toggle(key: .hideNonNotchedFromMissionControl) {
                    Text("Hide windows on non-notch displays from Mission Control")
                }
            } header: {
                Text("Window Behavior")
            }
            
            Section {
                Defaults.Toggle(key: .normalizeGestureDirection) {
                    Text("Normalize gesture direction")
                }
            } header: {
                Text("Miscellaneous")
            }
            
            Section {
                HStack {
                    ForEach(icons, id: \.self) { icon in
                        Spacer()
                        VStack {
                            Image(icon)
                                .resizable()
                                .frame(width: 80, height: 80)
                                .background(
                                    RoundedRectangle(cornerRadius: 20, style: .circular)
                                        .strokeBorder(
                                            icon == selectedIcon ? Color.effectiveAccent : .clear,
                                            lineWidth: 2.5
                                        )
                                )

                            Text("Default")
                                .fontWeight(.medium)
                                .font(.caption)
                                .foregroundStyle(icon == selectedIcon ? .white : .secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(icon == selectedIcon ? Color.effectiveAccent : .clear)
                                )
                        }
                        .onTapGesture {
                            withAnimation {
                                selectedIcon = icon
                            }
                            NSApp.applicationIconImage = NSImage(named: icon)
                        }
                        Spacer()
                    }
                }
                .disabled(true)
            } header: {
                HStack {
                    Text("App icon")
                    comingSoonBadge()
                }
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Advanced")
    }
}
