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
        HStack(alignment: .top, spacing: 15) {
            countdownRing
                .padding(.all, 5)

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    centerCopy
                    presetRow
                }
                .padding(.top, 10)
                .padding(.leading, 5)

                Spacer(minLength: 0)

                Divider()
                    .overlay(Color.white.opacity(0.10))
                    .padding(.vertical, 8)

                controlRow
                    .padding(.bottom, 2)

                Spacer(minLength: 0)
            }
            .frame(maxHeight: .infinity)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var countdownRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 7)

            Circle()
                .trim(from: 0, to: max(0.01, 1 - model.countdownState.progress))
                .stroke(
                    Color.white,
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 4) {
                Text(model.displayTime)
                    .font(.headline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(model.phaseTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 144)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Timer")
        .accessibilityValue(model.accessibilitySummary)
    }

    private var centerCopy: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.displayTime)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)

            Text(model.phaseTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var presetRow: some View {
        HStack(spacing: 16) {
            ForEach(TimerWidgetModel.presets) { preset in
                Button {
                    model.selectPreset(preset)
                } label: {
                    Text(preset.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(isSelectedPreset(preset) ? 1 : 0.45))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var controlRow: some View {
        HStack(spacing: 16) {
            HoverButton(
                icon: model.countdownState.phase == .running ? "pause.fill" : "play.fill",
                iconColor: .white,
                scale: .large
            ) {
                model.toggleStartPause()
            }
            .opacity(primaryControlOpacity)
            .help(model.countdownState.phase == .running ? "Pause" : "Start")

            HoverButton(
                icon: "arrow.counterclockwise",
                iconColor: .white,
                scale: .large
            ) {
                model.reset()
            }
            .opacity(secondaryControlOpacity)
            .help("Reset")
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var primaryControlOpacity: Double {
        model.countdownState.phase == .running ? 1 : 0.7
    }

    private var secondaryControlOpacity: Double {
        model.countdownState.phase == .idle ? 0.45 : 0.7
    }

    private func isSelectedPreset(_ preset: TimerPreset) -> Bool {
        model.selectedPreset == preset
    }
}

#Preview("Timer Widget") {
    TimerWidgetPreviewHost()
        .frame(width: 440, height: 180)
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
