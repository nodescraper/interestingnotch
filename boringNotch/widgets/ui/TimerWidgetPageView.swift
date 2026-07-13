//
//  TimerWidgetPageView.swift
//  boringNotch
//
//  Created by Codex on 2026-07-13.
//

import SwiftUI

struct TimerWidgetPageView: View {
    let widget: Widget

    @ObservedObject var model: TimerWidgetModel

    var body: some View {
        HStack(alignment: .center, spacing: 30) {
            countdownRing

            VStack(alignment: .leading, spacing: 20) {
                centerCopy
                presetRow
                controlRow
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
        .padding(.top, 16)
        .padding(.bottom, 26)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var countdownRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 10)

            Circle()
                .trim(from: 0, to: max(0.01, 1 - model.countdownState.progress))
                .stroke(
                    Color.white,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 6) {
                Text(model.displayTime)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)

                Text(model.phaseTitle)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
        }
        .frame(width: 168, height: 168)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Timer")
        .accessibilityValue(model.accessibilitySummary)
    }

    private var centerCopy: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(widget.manifest.name)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("A simple countdown now, structured so Pomodoro phases can layer in later.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var presetRow: some View {
        HStack(spacing: 10) {
            ForEach(TimerWidgetModel.presets) { preset in
                Button {
                    model.selectPreset(preset)
                } label: {
                    Text(preset.label)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(isSelectedPreset(preset) ? .black : .white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background {
                            Capsule()
                                .fill(isSelectedPreset(preset) ? Color.white : Color.white.opacity(0.08))
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var controlRow: some View {
        HStack(spacing: 12) {
            Button {
                model.toggleStartPause()
            } label: {
                Label(
                    model.countdownState.phase == .running ? "Pause" : "Start",
                    systemImage: model.countdownState.phase == .running ? "pause.fill" : "play.fill"
                )
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background {
                    Capsule()
                        .fill(Color.white)
                }
            }
            .buttonStyle(.plain)

            Button {
                model.reset()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 9)
                    .background {
                        Capsule()
                            .fill(Color(nsColor: .secondarySystemFill))
                    }
            }
            .buttonStyle(.plain)
        }
    }

    private func isSelectedPreset(_ preset: TimerPreset) -> Bool {
        model.selectedPreset == preset
    }
}

#Preview("Timer Widget") {
    TimerWidgetPreviewHost()
        .frame(width: 540, height: 280)
        .background(.black)
}

private struct TimerWidgetPreviewHost: View {
    @MainActor
    private let model = TimerWidgetModel(widgetID: "timer-preview")

    var body: some View {
        if let widget = previewWidget {
            TimerWidgetPageView(widget: widget, model: model)
        }
    }

    @MainActor
    private var previewWidget: Widget? {
        try? Widget(
            manifest: WidgetManifest(
                schema: 1,
                kind: .interactive,
                id: "timer",
                name: "Timer",
                author: "Preview",
                source: nil,
                extract: nil,
                render: .init(
                    template: .iconLabel,
                    slots: [
                        "icon": .string("timer"),
                        "label": .string("Countdown timer"),
                        "color": .string("accent"),
                    ]
                ),
                onTap: nil,
                permissions: nil,
                interactive: .init(type: .timer)
            ),
            interactiveRuntime: model,
            status: .ok
        )
    }
}
