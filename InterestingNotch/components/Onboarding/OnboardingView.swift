//
//  OnboardingView.swift
//  InterestingNotch
//
//  Created by Alexander on 2025-06-23.
//

import SwiftUI
import AVFoundation
import Defaults
import Sparkle

enum OnboardingStep {
    case welcome
    case cameraPermission
    case calendarPermission
    case remindersPermission
    case accessibilityPermission
    case musicPermission
    case widgetSelection
    case softwareUpdatePermission
    case finished
}

private let calendarService = CalendarService()

struct OnboardingView: View {
    @State var step: OnboardingStep = .welcome
    let updater: SPUUpdater?
    let onFinish: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        ZStack {
            switch step {
            case .welcome:
                WelcomeView {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        step = .cameraPermission
                    }
                }
                .transition(.opacity)

            case .cameraPermission:
                PermissionRequestView(
                    icon: Image(systemName: "camera.fill"),
                    title: "Enable Camera Access",
                    description: "InterestingNotch includes a mirror feature that lets you quickly check your appearance using your camera, right from the notch. Camera access is required only to show this live preview. You can turn the mirror feature on or off at any time in the app.",
                    privacyNote: "Your camera is never used without your consent, and nothing is recorded or stored.",
                    onAllow: {
                        Task {
                            await requestCameraPermission()
                            withAnimation(.easeInOut(duration: 0.6)) {
                                step = .calendarPermission
                            }
                        }
                    },
                    onSkip: {
                        withAnimation(.easeInOut(duration: 0.6)) {
                            step = .calendarPermission
                        }
                    }
                )
                .transition(.opacity)

            case .calendarPermission:
                PermissionRequestView(
                    icon: Image(systemName: "calendar"),
                    title: "Enable Calendar Access",
                    description: "InterestingNotch can show all your upcoming events in one place. Access to your calendar is needed to display your schedule.",
                    privacyNote: "Your calendar data is only used to show your events and is never shared.",
                    onAllow: {
                        Task {
                                await requestCalendarPermission()
                                withAnimation(.easeInOut(duration: 0.6)) {
                                    step = .remindersPermission
                                }
                        }
                    },
                    onSkip: {
                            withAnimation(.easeInOut(duration: 0.6)) {
                                step = .remindersPermission
                            }
                    }
                )
                .transition(.opacity)

                case .remindersPermission:
                    PermissionRequestView(
                        icon: Image(systemName: "checklist"),
                        title: "Enable Reminders Access",
                        description: "InterestingNotch can show your scheduled reminders alongside your calendar events. Access to Reminders is needed to display your reminders.",
                        privacyNote: "Your reminders data is only used to show your reminders and is never shared.",
                        onAllow: {
                            Task {
                                await requestRemindersPermission()
                                withAnimation(.easeInOut(duration: 0.6)) {
                                    step = nextStepAfterReminders()
                                }
                            }
                        },
                        onSkip: {
                            withAnimation(.easeInOut(duration: 0.6)) {
                                step = nextStepAfterReminders()
                            }
                        }
                    )
                    .transition(.opacity)

            case .accessibilityPermission:
                PermissionRequestView(
                    icon: Image(systemName: "hand.raised.fill"),
                    title: "Enable Accessibility Access",
                    description: "Accessibility access is only needed when using built-in macOS control sources for OSD replacement. External sources like BetterDisplay or Lunar do not require Accessibility. You can enable it later in OSD settings if needed.",
                    privacyNote: "Accessibility access is used only to improve media and brightness notifications. No data is collected or shared.",
                    onAllow: {
                        Task {
                            _ = await MediaKeyInterceptor.shared.ensureAccessibilityAuthorization(promptIfNeeded: true)
                            await MainActor.run {
                                withAnimation(.easeInOut(duration: 0.6)) {
                                    step = .musicPermission
                                }
                            }
                        }
                    },
                    onSkip: {
                        withAnimation(.easeInOut(duration: 0.6)) {
                            step = .musicPermission
                        }
                    }
                )
                .transition(.opacity)
                
            case .musicPermission:
                MusicControllerSelectionView(
                    onContinue: {
                        withAnimation(.easeInOut(duration: 0.6)) {
                            step = .widgetSelection
                        }
                    }
                )
                .transition(.opacity)

            case .widgetSelection:
                WidgetSelectionView(
                    onContinue: {
                        withAnimation(.easeInOut(duration: 0.6)) {
                            if InterestingViewCoordinator.shared.firstLaunch {
                                step = .softwareUpdatePermission
                            } else {
                                step = .finished
                            }
                        }
                    }
                )
                .transition(.opacity)

            case .softwareUpdatePermission:
                SoftwareUpdatePermissionView(
                    updater: updater,
                    onContinue: {
                        withAnimation(.easeInOut(duration: 0.6)) {
                            InterestingViewCoordinator.shared.firstLaunch = false
                            step = .finished
                        }
                    }
                )
                .transition(.opacity)

            case .finished:
                OnboardingFinishView(onFinish: onFinish, onOpenSettings: onOpenSettings)
            }
        }
        .frame(width: 400, height: 600)
    }

    // MARK: - Permission Request Logic

    func requestCameraPermission() async {
        await AVCaptureDevice.requestAccess(for: .video)
    }

    func requestCalendarPermission() async {
        _ = try? await calendarService.requestAccess(to: .event)
    }

    func requestRemindersPermission() async {
        _ = try? await calendarService.requestAccess(to: .reminder)
    }

    func nextStepAfterReminders() -> OnboardingStep {
        return .accessibilityPermission
    }
    
}

@MainActor
struct WidgetSelectionView: View {
    @ObservedObject private var engine = WidgetEngine.shared
    @State private var selectedIDs: Set<String>

    let onContinue: () -> Void

    init(onContinue: @escaping () -> Void) {
        self.onContinue = onContinue
        _selectedIDs = State(initialValue: Set(Defaults[.pinnedWidgetIDs]))
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 52))
                .foregroundColor(.effectiveAccent)
                .padding(.top, 24)

            Text("Choose Your Widgets")
                .font(.title)
                .fontWeight(.semibold)

            Text("Select the widgets you want to appear as tabs in your notch. You can change this later in the Workshop.")
                .multilineTextAlignment(.center)
                .font(.body)
                .foregroundColor(.secondary)
                .padding(.horizontal, 28)

            ScrollView {
                VStack(spacing: 10) {
                    if engine.widgets.isEmpty {
                        VStack(spacing: 8) {
                            ProgressView()
                            Text("Loading available widgets...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                    } else {
                        ForEach(engine.widgets, id: \.id) { widget in
                            WidgetSelectionRow(
                                widget: widget,
                                isSelected: selectedIDs.contains(widget.id)
                            ) {
                                toggle(widget.id)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
            }
            .scrollDisabled(engine.widgets.count <= 4)

            Text("Active widgets appear next to Home and Shelf in the notch.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button("Continue") {
                Defaults[.pinnedWidgetIDs] = engine.widgets
                    .map(\.id)
                    .filter { selectedIDs.contains($0) }
                onContinue()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.bottom, 24)
            .keyboardShortcut(.defaultAction)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()
        )
    }

    private func toggle(_ widgetID: String) {
        if selectedIDs.contains(widgetID) {
            selectedIDs.remove(widgetID)
        } else {
            selectedIDs.insert(widgetID)
        }
    }
}

private struct WidgetSelectionRow: View {
    let widget: Widget
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.title3)
                    .frame(width: 28, height: 28)
                    .foregroundStyle(widget.resolvedColor)

                VStack(alignment: .leading, spacing: 3) {
                    Text(widget.manifest.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(WorkshopWidgetCatalog.description(for: widget))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.effectiveAccent : .secondary.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.effectiveAccent.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.effectiveAccent.opacity(0.7) : Color.secondary.opacity(0.25), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var iconName: String {
        WidgetSlotRenderer.resolvedString(
            forSlotNamed: "icon",
            in: widget.manifest.render.slots,
            value: widget.lastValue,
            fallback: "square.grid.2x2"
        )
    }
}

struct SoftwareUpdatePermissionView: View {
    let updater: SPUUpdater?
    let onContinue: () -> Void

    @State private var automaticallyChecksForUpdates = true
    @State private var automaticallyDownloadsUpdates = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                .font(.system(size: 64))
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(.effectiveAccent)

            Text("Keep InterestingNotch Updated")
                .font(.title)
                .fontWeight(.semibold)

            Text("InterestingNotch can check for updates in the background. You can still check manually from the menu bar at any time.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 34)

            VStack(alignment: .leading, spacing: 12) {
                Toggle("Check for updates automatically", isOn: $automaticallyChecksForUpdates)

                Toggle("Download and install updates automatically", isOn: $automaticallyDownloadsUpdates)
                    .disabled(!automaticallyChecksForUpdates)
                    .opacity(automaticallyChecksForUpdates ? 1 : 0.45)
            }
            .toggleStyle(.checkbox)
            .padding(.horizontal, 44)
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            Button("Continue") {
                applyUpdatePreference(
                    checksAutomatically: automaticallyChecksForUpdates,
                    downloadsAutomatically: automaticallyChecksForUpdates && automaticallyDownloadsUpdates
                )
                onContinue()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()
        )
        .onChange(of: automaticallyChecksForUpdates) { _, enabled in
            if !enabled {
                automaticallyDownloadsUpdates = false
            }
        }
    }

    private func applyUpdatePreference(checksAutomatically: Bool, downloadsAutomatically: Bool) {
        guard let updater else {
            UserDefaults.standard.set(checksAutomatically, forKey: "SUEnableAutomaticChecks")
            UserDefaults.standard.set(downloadsAutomatically, forKey: "SUAutomaticallyUpdate")
            return
        }

        updater.automaticallyChecksForUpdates = checksAutomatically
        updater.automaticallyDownloadsUpdates = downloadsAutomatically
    }
}
