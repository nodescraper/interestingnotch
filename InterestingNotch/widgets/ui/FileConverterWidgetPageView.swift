//
//  FileConverterWidgetPageView.swift
//  InterestingNotch
//
//  Created by Codex on 2026-07-17.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct FileConverterWidgetPageView: View {
    let widget: Widget

    @ObservedObject var model: FileConverterWidgetModel

    private let accent = Color.effectiveAccent
    private let success = Color(hex: "#30D158") ?? .green

    // Shared with the Timer so the circle buttons match exactly.
    private let circleButtonSize: CGFloat = 44
    private let resetSurface = Color(red: 0.16, green: 0.16, blue: 0.17)

    // Timer-style tinted surfaces: a soft surface behind an accent/green icon.
    private var accentSurface: Color { accent.opacity(0.18) }
    private var successSurface: Color { success.opacity(0.18) }

    var body: some View {
        converterPanel
            .contentShape(Rectangle())
            .onDrop(of: [.fileURL], isTargeted: $model.isDropTargeted) { providers in
                model.handleDrop(providers: providers)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(FileConverterWidgetModel.stageSpring, value: stateKey)
    }

    private var converterPanel: some View {
        ZStack {
            // Dashed border only in the idle (drop) state. Once a file is
            // loaded / converting / done, drop the border entirely.
            if isIdle {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        model.isDropTargeted
                            ? accent.opacity(0.9)
                            : Color.white.opacity(0.1),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [10])
                    )
                    .transition(.opacity)
            }

            stageContent
                .padding()
        }
        .transaction { transaction in
            transaction.animation = FileConverterWidgetModel.stageSpring
        }
    }

    private var isIdle: Bool {
        if case .idle = model.state { return true }
        return false
    }

    @ViewBuilder
    private var stageContent: some View {
        ZStack {
            ZStack {
                switch model.state {
                case .idle:
                    idleStage
                case .loaded(let loaded):
                    loadedStage(loaded)
                case .converting(let loaded):
                    convertingStage(loaded)
                case .done(let output):
                    doneStage(output)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var stateKey: String {
        switch model.state {
        case .idle: return "idle"
        case .loaded: return "loaded"
        case .converting: return "converting"
        case .done: return "done"
        }
    }

    private var idleStage: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray.and.arrow.down")
                .symbolVariant(.fill)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(model.isDropTargeted ? accent : .white, .gray)
                .imageScale(.large)
                .scaleEffect(model.isDropTargeted ? 1.06 : 1)

            Text("Drop a file to convert")
                .foregroundStyle(.gray)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.medium)

            if let error = model.inlineErrorMessage, !error.isEmpty {
                Text(error)
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundStyle(accent)
                    .multilineTextAlignment(.center)
            } else {
                Text("Images · PDF · Text")
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundStyle(.gray.opacity(0.72))
            }
        }
        .animation(.spring(response: 0.36, dampingFraction: 0.7), value: model.isDropTargeted)
        .transition(stageTransition)
    }

    private func loadedStage(_ loaded: FileConverterLoadedFile) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                thumbnailView(loaded)

                VStack(alignment: .leading, spacing: 4) {
                    Text(loaded.filename)
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    HStack(spacing: 4) {
                        Text("to")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.58))

                        Button {
                            model.setShowsTargetOptions(!model.showsTargetOptions)
                        } label: {
                            Text(loaded.targetDisplayName)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(accent)
                                .overlay(alignment: .bottom) {
                                    Rectangle()
                                        .fill(accent.opacity(0.45))
                                        .frame(height: 1)
                                        .offset(y: 3)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer(minLength: 12)

                // ✕ — same size/shape as the Timer's cancel button, and same
                // size as the → action (44), using the Timer's grey surface.
                Button {
                    model.reset()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: circleButtonSize, height: circleButtonSize)
                        .background(resetSurface, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)

                Button {
                    model.convert()
                } label: {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(accent)
                        .frame(width: circleButtonSize, height: circleButtonSize)
                        .background(accentSurface, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }

            if model.showsTargetOptions {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(loaded.targetOptions, id: \.identifier) { target in
                            let isSelected = target == loaded.selectedTarget
                            Button {
                                model.selectTarget(target)
                                model.setShowsTargetOptions(false)
                            } label: {
                                Text(target.interestingDisplayName)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(isSelected ? .black.opacity(0.92) : .white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(isSelected ? accent : .white.opacity(0.07))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
        }
        .transition(stageTransition)
    }

    private func convertingStage(_ loaded: FileConverterLoadedFile) -> some View {
        VStack(spacing: 10) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(accent)
                .scaleEffect(1.2)

            Text("Converting \(loaded.conversionLabel)…")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(stageTransition)
    }

    private func doneStage(_ output: FileConverterOutput) -> some View {
        HStack(spacing: 12) {
            // Green checkmark in the same tinted style as the → button
            // (surface + icon), just green instead of accent.
            ZStack {
                Circle()
                    .fill(successSurface)
                    .frame(width: circleButtonSize, height: circleButtonSize)

                Image(systemName: "checkmark")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(success)
            }

            // Filename on top, size · saved below — same style as step 2's
            // filename + "to …" block.
            VStack(alignment: .leading, spacing: 4) {
                Text(output.filename)
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text("\(output.sizeDescription) · \(output.savedDescription)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            // Open the converted file directly.
            Button {
                model.openOutput()
            } label: {
                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: circleButtonSize, height: circleButtonSize)
                    .background(resetSurface, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Open file")

            // Reveal in Finder — folder icon, grey surface like the ✕.
            Button {
                model.revealInFinder()
            } label: {
                Image(systemName: "folder")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: circleButtonSize, height: circleButtonSize)
                    .background(resetSurface, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Reveal in Finder")

            // Convert another — accent tinted, matches the → button style.
            Button {
                model.reset()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(width: circleButtonSize, height: circleButtonSize)
                    .background(accentSurface, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Convert another file")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(stageTransition)
    }

    @ViewBuilder
    private func thumbnailView(_ loaded: FileConverterLoadedFile) -> some View {
        Group {
            if let thumbnail = loaded.thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.08), .white.opacity(0.03)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Image(systemName: loaded.iconName)
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.88))
                }
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var stageTransition: AnyTransition {
        .scale(scale: 0.8).combined(with: .opacity)
    }
}
