//
//  ChannelExecutor.swift
//  boringNotch
//
//  Created by Codex on 2026-07-13.
//

import Foundation

protocol ChannelExecutor: Sendable {
    var channelType: WidgetManifest.Source.ChannelType { get }
    func run(source: WidgetManifest.Source) async throws -> String
}

enum WidgetCommandAllowlist {
    static let executables: Set<String> = [
        "git",
        "brew",
        "gh",
        "node",
        "pnpm",
        "python3",
        "swift",
        "defaults",
        "pmset",
        "networksetup",
        "system_profiler",
        "ioreg",
        "osascript",
        "open",
        "cat",
    ]
}

enum ChannelExecutorError: LocalizedError, Equatable, Sendable {
    case unsupportedSourceType(expected: WidgetManifest.Source.ChannelType, actual: WidgetManifest.Source.ChannelType)
    case missingCommand
    case invalidCommand(String)
    case executableNotAllowed(String)
    case executableNotFound(String)
    case failedToStart(String)
    case timedOut(TimeInterval)
    case nonZeroExit(executable: String, code: Int32, stderr: String)

    var errorDescription: String? {
        switch self {
        case .unsupportedSourceType(let expected, let actual):
            return "Channel executor expected \(expected.rawValue), got \(actual.rawValue)"
        case .missingCommand:
            return "Command source is missing a run string."
        case .invalidCommand(let details):
            return "Command could not be parsed: \(details)"
        case .executableNotAllowed(let executable):
            return "Executable '\(executable)' is not in the widget allowlist."
        case .executableNotFound(let executable):
            return "Executable '\(executable)' could not be found."
        case .failedToStart(let details):
            return "Command failed to start: \(details)"
        case .timedOut(let timeout):
            return "Command exceeded timeout of \(timeout) seconds."
        case .nonZeroExit(let executable, let code, let stderr):
            if stderr.isEmpty {
                return "Command '\(executable)' exited with code \(code)."
            }
            return "Command '\(executable)' exited with code \(code): \(stderr)"
        }
    }
}

struct CommandExecutor: ChannelExecutor {
    let channelType: WidgetManifest.Source.ChannelType = .command

    func run(source: WidgetManifest.Source) async throws -> String {
        guard source.type == .command else {
            throw ChannelExecutorError.unsupportedSourceType(expected: .command, actual: source.type)
        }

        guard let rawCommand = source.run?.trimmingCharacters(in: .whitespacesAndNewlines), !rawCommand.isEmpty else {
            throw ChannelExecutorError.missingCommand
        }

        let parsedCommand = try ParsedCommand(raw: rawCommand)
        let environment = mergedEnvironment(with: source.env)
        let executableURL = try resolveExecutableURL(for: parsedCommand.executable, environment: environment)

        let process = Process()
        process.executableURL = executableURL
        process.arguments = parsedCommand.arguments.map(Self.expandTildeIfNeeded)
        process.environment = environment

        if let cwd = source.cwd {
            process.currentDirectoryURL = URL(fileURLWithPath: Self.expandTildeIfNeeded(cwd))
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let stdoutBuffer = OutputBuffer()
        let stderrBuffer = OutputBuffer()
        let timedOut = TimeoutState()

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if chunk.isEmpty {
                handle.readabilityHandler = nil
            } else {
                stdoutBuffer.append(chunk)
            }
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if chunk.isEmpty {
                handle.readabilityHandler = nil
            } else {
                stderrBuffer.append(chunk)
            }
        }

        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let resumeBox = ContinuationBox(continuation: continuation)

            process.terminationHandler = { finishedProcess in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil

                stdoutBuffer.append(stdoutPipe.fileHandleForReading.readDataToEndOfFile())
                stderrBuffer.append(stderrPipe.fileHandleForReading.readDataToEndOfFile())

                if timedOut.value {
                    resumeBox.resume(with: .failure(.timedOut(source.timeout ?? 0)))
                    return
                }

                let stdout = String(decoding: stdoutBuffer.data, as: UTF8.self)
                let stderr = String(decoding: stderrBuffer.data, as: UTF8.self)
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if finishedProcess.terminationStatus == 0 {
                    resumeBox.resume(with: .success(stdout))
                } else {
                    resumeBox.resume(
                        with: .failure(
                            .nonZeroExit(
                                executable: executableURL.lastPathComponent,
                                code: finishedProcess.terminationStatus,
                                stderr: stderr
                            )
                        )
                    )
                }
            }

            do {
                try process.run()
            } catch {
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                resumeBox.resume(with: .failure(.failedToStart(error.localizedDescription)))
                return
            }

            if let timeout = source.timeout, timeout > 0 {
                Task {
                    try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    if process.isRunning {
                        timedOut.markTimedOut()
                        process.terminate()
                    }
                }
            }
        }

        return result
    }

    private func mergedEnvironment(with overrides: [String: String]?) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        overrides?.forEach { key, value in
            environment[key] = Self.expandTildeIfNeeded(value)
        }
        return environment
    }

    private func resolveExecutableURL(for executable: String, environment: [String: String]) throws -> URL {
        let expandedExecutable = Self.expandTildeIfNeeded(executable)
        let executableName = URL(fileURLWithPath: expandedExecutable).lastPathComponent

        guard WidgetCommandAllowlist.executables.contains(executableName) else {
            throw ChannelExecutorError.executableNotAllowed(executableName)
        }

        if expandedExecutable.contains("/") {
            let url = URL(fileURLWithPath: expandedExecutable)
            guard FileManager.default.isExecutableFile(atPath: url.path) else {
                throw ChannelExecutorError.executableNotFound(expandedExecutable)
            }
            return url
        }

        let pathEntries = (environment["PATH"] ?? ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)

        for entry in pathEntries {
            let candidate = URL(fileURLWithPath: entry).appendingPathComponent(executableName)
            if FileManager.default.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }

        throw ChannelExecutorError.executableNotFound(executableName)
    }

    private static func expandTildeIfNeeded(_ value: String) -> String {
        (value as NSString).expandingTildeInPath
    }
}

private struct ParsedCommand {
    let executable: String
    let arguments: [String]

    init(raw: String) throws {
        let tokens = try Self.tokenize(raw)
        guard let executable = tokens.first else {
            throw ChannelExecutorError.invalidCommand("No executable found.")
        }

        self.executable = executable
        self.arguments = Array(tokens.dropFirst())
    }

    private static func tokenize(_ input: String) throws -> [String] {
        var tokens: [String] = []
        var current = ""
        var iterator = input.makeIterator()
        var quote: Character?
        var isEscaping = false

        while let character = iterator.next() {
            if isEscaping {
                current.append(character)
                isEscaping = false
                continue
            }

            if character == "\\" && quote != "'" {
                isEscaping = true
                continue
            }

            if character == "\"" || character == "'" {
                if quote == character {
                    quote = nil
                } else if quote == nil {
                    quote = character
                } else {
                    current.append(character)
                }
                continue
            }

            if character.isWhitespace && quote == nil {
                if !current.isEmpty {
                    tokens.append(current)
                    current.removeAll(keepingCapacity: true)
                }
                continue
            }

            current.append(character)
        }

        if isEscaping {
            throw ChannelExecutorError.invalidCommand("Trailing escape character.")
        }

        if quote != nil {
            throw ChannelExecutorError.invalidCommand("Unterminated quoted string.")
        }

        if !current.isEmpty {
            tokens.append(current)
        }

        return tokens
    }
}

private final class ContinuationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<String, Error>?

    init(continuation: CheckedContinuation<String, Error>) {
        self.continuation = continuation
    }

    func resume(with result: Result<String, ChannelExecutorError>) {
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()

        guard let continuation else { return }
        continuation.resume(with: result.mapError { $0 as Error })
    }
}

private final class OutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    var data: Data {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func append(_ data: Data) {
        guard !data.isEmpty else { return }
        lock.lock()
        storage.append(data)
        lock.unlock()
    }
}

private final class TimeoutState: @unchecked Sendable {
    private let lock = NSLock()
    private var timedOut = false

    var value: Bool {
        lock.lock()
        defer { lock.unlock() }
        return timedOut
    }

    func markTimedOut() {
        lock.lock()
        timedOut = true
        lock.unlock()
    }
}
