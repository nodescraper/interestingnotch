//
//  TimerWidgetPageView.swift
//  boringNotch
//
//  Created by Codex on 2026-07-13.
//

import SwiftUI

struct TimerWidgetPageView: View {
    let widget: Widget

    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject var model: TimerWidgetModel
    let animationNamespace: Namespace.ID?
    private let timerVisualBlockSize: CGFloat = 100
    private let timerRingSize: CGFloat = 100

    var body: some View {
        HStack(alignment: .bottom, spacing: 22) {
            countdownRing
                .frame(width: timerVisualBlockSize, height: timerVisualBlockSize)
                .padding(.leading, 15)
                .padding(.bottom, 20)

            timerControls
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    private var countdownRing: some View {
        if let animationNamespace {
            timerRing
                .matchedGeometryEffect(id: "timer-ring", in: animationNamespace)
        } else {
            timerRing
        }
    }

    private var timerRing: some View {
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
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.gray)
                    .textCase(.uppercase)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(width: timerRingSize, height: timerRingSize)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Timer")
        .accessibilityValue(model.accessibilitySummary)
    }

    private var timerControls: some View {
        VStack(alignment: .leading) {
            timerInfoAndPresets
            controlRow
        }
    }

    private var timerInfoAndPresets: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 4) {
                centerCopy(width: geo.size.width)
                presetTrack
            }
        }
        .padding(.top, 10)
        .padding(.leading, 5)
    }

    private func centerCopy(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(model.displayTime)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .frame(width: width, alignment: .leading)

            Text(model.phaseTitle)
                .font(.headline)
                .fontWeight(.medium)
                .foregroundStyle(.gray)
                .lineLimit(1)
                .frame(width: width, alignment: .leading)
        }
    }

    private var presetTrack: some View {
        VStack(alignment: .leading, spacing: 5) {
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
            
            Divider()
                .overlay(Color.white.opacity(0.10))
        }
        .frame(height: 36, alignment: .top)
    }

    private var controlRow: some View {
        HStack(spacing: 6) {
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
                scale: .medium
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
            TimerWidgetPageView(widget: widget, model: model, animationNamespace: nil)
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
