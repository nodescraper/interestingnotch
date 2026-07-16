//
//  VoiceRecorderWidgetPageView.swift
//  InterestingNotch
//
//  Created by Codex on 2026-07-15.
//  Signature element: a live waveform that reacts to the mic while recording
//  and rests as a flat baseline when idle — the way Voice Memos shows sound.
//

import SwiftUI

struct VoiceRecorderWidgetPageView: View {
    let widget: Widget

    @ObservedObject var model: VoiceRecorderWidgetModel

    private let accent = Color.effectiveAccent
    private let accentSurface = Color.effectiveAccent.opacity(0.18)
    private let resetSurface = Color(red: 0.16, green: 0.16, blue: 0.17)

    // Sizing to match the timer widget.
    private let circleButtonSize: CGFloat = 44
    private let bigTimeSize: CGFloat = 34

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetTitleRow(
                title: model.statusTitle,
                caption: model.statusMessage,
                titleColor: model.isRecording ? accent : .white
            ) {
                if case .permissionDenied = model.phase {
                    iconCircleButton(systemImage: "gearshape", tint: .white) {
                        model.openMicrophoneSettings()
                    }
                    .help("Open microphone settings")
                } else {
                    iconCircleButton(systemImage: "folder", tint: .white) {
                        model.revealLastRecording()
                    }
                    .disabled(!model.hasSavedRecording)
                    .opacity(model.hasSavedRecording ? 1 : 0.4)
                    .help("Reveal in Finder")
                }
            }

            // Signature: the waveform, filling the middle.
            WaveformView(
                levels: model.levels,
                isActive: model.isRecording,
                color: accent
            )
            .frame(maxWidth: .infinity)
            .frame(height: 24)

            // Bottom row: record + play (left), time (right).
            HStack(alignment: .center, spacing: 12) {
                recordButton

                playButton
                    .disabled(!model.hasSavedRecording)
                    .opacity(model.hasSavedRecording ? 1 : 0.4)

                Spacer(minLength: 12)

                Text(model.displayTime)
                    .font(.system(size: bigTimeSize, weight: .regular, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(model.isRecording ? accent : .white.opacity(0.9))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Voice Recorder")
        .accessibilityValue(model.displayTime)
    }

    // MARK: - Buttons

    private var recordButton: some View {
        Button {
            model.toggleRecording()
        } label: {
            Image(systemName: model.isRecording ? "stop.fill" : "mic.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(accent)
                .frame(width: circleButtonSize, height: circleButtonSize)
                .background(accentSurface, in: Circle())
                .overlay(
                    Circle().strokeBorder(accent.opacity(model.isRecording ? 0.5 : 0), lineWidth: 1)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: model.isRecording)
        .help(model.isRecording ? "Stop" : "Record")
    }

    private var playButton: some View {
        Button {
            model.openLastRecording()
        } label: {
            Image(systemName: "play.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: circleButtonSize, height: circleButtonSize)
                .background(resetSurface, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Play last recording")
    }

    private func iconCircleButton(
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.08), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Waveform

/// Renders the rolling level buffer as symmetric bars around a center line.
/// A single Canvas draw keeps it cheap even at 60 ticks/sec.
private struct WaveformView: View {
    let levels: [Float]
    let isActive: Bool
    let color: Color

    var body: some View {
        Canvas { ctx, size in
            let count = levels.count
            guard count > 0 else { return }

            let barSpacing: CGFloat = 1.5
            let totalSpacing = barSpacing * CGFloat(count - 1)
            let barWidth = max(1, (size.width - totalSpacing) / CGFloat(count))
            let midY = size.height / 2
            let maxBar = size.height / 2

            for (i, level) in levels.enumerated() {
                let x = CGFloat(i) * (barWidth + barSpacing)
                let h = isActive
                    ? max(2, CGFloat(level) * maxBar)
                    : 1.5
                let rect = CGRect(x: x, y: midY - h, width: barWidth, height: h * 2)
                let path = Path(roundedRect: rect, cornerRadius: barWidth / 2)

                let recency = Double(i) / Double(max(count - 1, 1))
                let opacity = isActive ? (0.4 + 0.6 * recency) : 0.22
                ctx.fill(path, with: .color(color.opacity(opacity)))
            }
        }
        .animation(.linear(duration: 0.06), value: levels)
        .drawingGroup()
    }
}

