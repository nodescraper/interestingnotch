//
//  VoiceRecorderWidgetModel.swift
//  InterestingNotch
//
//  Created by Codex on 2026-07-15.
//

import AppKit
import AVFoundation
import Foundation

enum VoiceRecorderPhase: Equatable, Sendable {
    case idle
    case recording
    case saved
    case permissionDenied
    case failure(String)
}

@MainActor
protocol VoiceRecorderSneakPeekControlling {
    func showRecorder()
    func hideRecorder()
}

@MainActor
struct SystemVoiceRecorderSneakPeekController: VoiceRecorderSneakPeekControlling {
    func showRecorder() {
        InterestingViewCoordinator.shared.toggleSneakPeek(status: true, type: .voiceRecorder, duration: 0)
    }

    func hideRecorder() {
        InterestingViewCoordinator.shared.toggleSneakPeek(status: false, type: .voiceRecorder)
    }
}

@MainActor
protocol VoiceRecorderFileRevealing {
    func open(_ url: URL)
    func reveal(_ url: URL)
    func openMicrophonePrivacySettings()
}

@MainActor
struct SystemVoiceRecorderFileRevealer: VoiceRecorderFileRevealing {
    func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func openMicrophonePrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}

@MainActor
final class VoiceRecorderWidgetModel: NSObject, ObservableObject, InteractiveWidgetRuntime {
    let interactiveKind: WidgetManifest.Interactive.Kind = .voiceRecorder
    let widgetID: String

    /// Number of bars in the live waveform.
    static let levelCount = 80

    @Published private(set) var phase: VoiceRecorderPhase = .idle
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var lastRecordingURL: URL?

    /// Rolling buffer of normalized (0...1) mic levels while recording, oldest→newest.
    /// Drives the live waveform; resets to flat when not recording.
    @Published private(set) var levels: [Float] = Array(repeating: 0, count: VoiceRecorderWidgetModel.levelCount)

    private let now: @Sendable () -> Date
    private let fileRevealer: any VoiceRecorderFileRevealing
    private let sneakPeekController: any VoiceRecorderSneakPeekControlling

    private var recorder: AVAudioRecorder?
    private var tickerTask: Task<Void, Never>?
    private var recordingStartedAt: Date?
    private var currentRecordingURL: URL?

    init(
        widgetID: String,
        now: @escaping @Sendable () -> Date = { Date() },
        fileRevealer: (any VoiceRecorderFileRevealing)? = nil,
        sneakPeekController: (any VoiceRecorderSneakPeekControlling)? = nil
    ) {
        self.widgetID = widgetID
        self.now = now
        self.fileRevealer = fileRevealer ?? SystemVoiceRecorderFileRevealer()
        self.sneakPeekController = sneakPeekController ?? SystemVoiceRecorderSneakPeekController()
        super.init()
    }

    deinit {
        tickerTask?.cancel()
    }

    var isRecording: Bool {
        phase == .recording
    }

    var hasSavedRecording: Bool {
        lastRecordingURL != nil
    }

    var displayTime: String {
        Self.formatDuration(elapsed)
    }

    var primaryButtonTitle: String {
        isRecording ? "Stop" : "Record"
    }

    var statusTitle: String {
        switch phase {
        case .idle:
            return hasSavedRecording ? "Ready for another take" : "Voice Recorder"
        case .recording:
            return "Recording"
        case .saved:
            return "Saved"
        case .permissionDenied:
            return "Microphone access needed"
        case .failure:
            return "Recording failed"
        }
    }

    var statusMessage: String {
        switch phase {
        case .idle:
            return hasSavedRecording ? (lastRecordingURL?.lastPathComponent ?? "Last recording saved.") : "Capture a quick voice note from the notch."
        case .recording:
            return "Recording to \(currentRecordingURL?.lastPathComponent ?? "voice note")"
        case .saved:
            return lastRecordingURL?.lastPathComponent ?? "Recording saved."
        case .permissionDenied:
            return "Allow microphone access in System Settings to record voice notes."
        case .failure(let message):
            return message
        }
    }

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            Task { await startRecording() }
        }
    }

    func revealLastRecording() {
        guard let lastRecordingURL else { return }
        fileRevealer.reveal(lastRecordingURL)
    }

    func openLastRecording() {
        guard let lastRecordingURL else { return }
        fileRevealer.open(lastRecordingURL)
    }

    func openMicrophoneSettings() {
        fileRevealer.openMicrophonePrivacySettings()
    }

    private func startRecording() async {
        guard await requestMicrophoneAccessIfNeeded() else {
            phase = .permissionDenied
            return
        }

        do {
            let recordingsDirectory = try Self.makeRecordingsDirectory()
            let url = recordingsDirectory.appendingPathComponent(Self.makeFileName(now: now()))
            let recorder = try AVAudioRecorder(url: url, settings: Self.recordingSettings)
            recorder.delegate = self
            recorder.isMeteringEnabled = true

            guard recorder.prepareToRecord(), recorder.record() else {
                throw VoiceRecorderError.unableToStart
            }

            self.recorder = recorder
            self.currentRecordingURL = url
            self.recordingStartedAt = now()
            self.elapsed = 0
            self.resetLevels()
            self.phase = .recording
            startTicker()
            sneakPeekController.showRecorder()
        } catch {
            teardownRecorder(deleteCurrentFile: true)
            phase = .failure(Self.errorMessage(for: error))
        }
    }

    private func stopRecording() {
        guard let recorder else { return }
        recorder.stop()
    }

    private func finishRecording(successfully flag: Bool) {
        stopTicker()

        if flag, let finishedURL = currentRecordingURL {
            elapsed = max(elapsed, now().timeIntervalSince(recordingStartedAt ?? now()))
            lastRecordingURL = finishedURL
            phase = .saved
            teardownRecorder(deleteCurrentFile: false)
        } else {
            teardownRecorder(deleteCurrentFile: true)
            phase = .failure("InterestingNotch couldn’t save that recording.")
        }

        resetLevels()
        sneakPeekController.hideRecorder()
    }

    private func teardownRecorder(deleteCurrentFile: Bool) {
        recorder?.delegate = nil
        recorder?.stop()
        recorder = nil
        recordingStartedAt = nil

        if deleteCurrentFile, let currentRecordingURL {
            try? FileManager.default.removeItem(at: currentRecordingURL)
        }

        currentRecordingURL = nil
    }

    private func startTicker() {
        stopTicker()
        tickerTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                await self.tick()
                try? await Task.sleep(for: .milliseconds(60))
            }
        }
    }

    private func stopTicker() {
        tickerTask?.cancel()
        tickerTask = nil
    }

    /// Runs on the recording ticker: refreshes elapsed time and pushes a new
    /// normalized mic level into the rolling buffer for the waveform.
    private func tick() async {
        updateElapsed()
        sampleLevel()
    }

    private func updateElapsed() {
        guard let recordingStartedAt else { return }
        elapsed = max(0, now().timeIntervalSince(recordingStartedAt))
    }

    private func sampleLevel() {
        guard let recorder else { return }
        recorder.updateMeters()
        let power = recorder.averagePower(forChannel: 0)   // dBFS, ~ -160...0
        let normalized = Self.normalizedLevel(fromDecibels: power)

        var next = levels
        next.removeFirst()
        next.append(normalized)
        levels = next
    }

    private func resetLevels() {
        levels = Array(repeating: 0, count: Self.levelCount)
    }

    /// Maps dBFS to a pleasing 0...1 bar height. Clamps the noise floor and
    /// applies a slight curve so quiet speech still shows movement.
    private static func normalizedLevel(fromDecibels db: Float) -> Float {
        let floor: Float = -55   // treat anything below this as silence
        guard db.isFinite else { return 0 }
        let clamped = max(floor, min(0, db))
        let linear = (clamped - floor) / (0 - floor)   // 0...1
        // Gentle ease so mid-level speech reads taller than a linear map.
        return powf(linear, 0.7)
    }

    private func requestMicrophoneAccessIfNeeded() async -> Bool {
        // On macOS, AVAudioApplication is the permission API for apps that
        // record audio. AVAudioRecorder may otherwise fail without causing
        // the app to appear in System Settings > Privacy & Security > Microphone.
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return true
        case .undetermined:
            return await AVAudioApplication.requestRecordPermission()
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    private static let recordingSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVSampleRateKey: 44_100,
        AVNumberOfChannelsKey: 1,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
    ]

    private static func makeRecordingsDirectory() throws -> URL {
        let directory = documentsDirectory
            .appendingPathComponent("InterestingNotch Recordings", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func makeFileName(now: Date) -> String {
        "Voice Note \(fileStampFormatter.string(from: now)).m4a"
    }

    private static func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded(.down)))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%02d:%02d", minutes, seconds)
    }

    private static func errorMessage(for error: Error) -> String {
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            return description
        }

        return error.localizedDescription
    }

    private static let fileStampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return formatter
    }()
}

extension VoiceRecorderWidgetModel: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.finishRecording(successfully: flag)
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor [weak self] in
            self?.stopTicker()
            self?.teardownRecorder(deleteCurrentFile: true)
            self?.phase = .failure(error.map(VoiceRecorderWidgetModel.errorMessage(for:)) ?? "InterestingNotch couldn’t encode that recording.")
        }
    }
}

private enum VoiceRecorderError: LocalizedError {
    case unableToStart

    var errorDescription: String? {
        switch self {
        case .unableToStart:
            return "InterestingNotch couldn’t start recording."
        }
    }
}
