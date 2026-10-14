import BrowCore
import Foundation
import os

enum MediaStatus: Equatable {
    /// The helper is not running (crashed, restarting, or MediaRemote refused us).
    case unavailable
    case nothing
    case playing(NowPlaying)
}

/// Runs `brow-media.pl … stream` under /usr/bin/perl, turns its JSON lines into
/// `MediaStatus`, and restarts it with backoff when it dies.
@MainActor
final class MediaController {
    private static let perl = URL(fileURLWithPath: "/usr/bin/perl")
    private static let logger = Logger(subsystem: "com.freedrobili.Brow", category: "media")

    private let scriptURL: URL
    private let libraryURL: URL
    private let onStatus: (MediaStatus) -> Void

    private var process: Process?
    /// Kept open for the helper's lifetime: when Brow dies the helper sees EOF and exits.
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private var buffer = Data()
    private var attempt = 0
    private var stopped = true
    private var restartTask: Task<Void, Never>?

    init(scriptURL: URL, libraryURL: URL, onStatus: @escaping (MediaStatus) -> Void) {
        self.scriptURL = scriptURL
        self.libraryURL = libraryURL
        self.onStatus = onStatus
    }

    func start() {
        stopped = false
        launch()
    }

    func stop() {
        stopped = true
        restartTask?.cancel()
        process?.terminate()
        cleanUp()
    }

    func send(_ command: MediaCommand) {
        let sender = Process()
        sender.executableURL = Self.perl
        sender.arguments = [scriptURL.path, libraryURL.path, "send"]
        sender.environment = ProcessInfo.processInfo.environment.merging(command.environment) { $1 }
        sender.standardOutput = FileHandle.nullDevice
        sender.standardError = FileHandle.nullDevice
        do {
            try sender.run()
        } catch {
            Self.logger.error("Media command failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func launch() {
        let helper = Process()
        helper.executableURL = Self.perl
        helper.arguments = [scriptURL.path, libraryURL.path, "stream"]
        let input = Pipe()
        let output = Pipe()
        helper.standardInput = input
        helper.standardOutput = output
        helper.standardError = FileHandle.nullDevice
        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.receive(data) } }
        }
        helper.terminationHandler = { [weak self] helper in
            let status = helper.terminationStatus
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.didTerminate(status: status) } }
        }
        do {
            try helper.run()
            process = helper
            inputPipe = input
            outputPipe = output
        } catch {
            Self.logger.error("Media helper did not start: \(error.localizedDescription, privacy: .public)")
            output.fileHandleForReading.readabilityHandler = nil
            didTerminate(status: -1)
        }
    }

    private func receive(_ data: Data) {
        guard !data.isEmpty else { return }   // EOF; the termination handler follows
        buffer.append(data)
        while let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) {
            let line = String(decoding: buffer[buffer.startIndex..<newline], as: UTF8.self)
            buffer.removeSubrange(buffer.startIndex...newline)
            guard let event = NowPlayingParser.parse(line: line) else {
                Self.logger.error("Skipping malformed media line (\(line.count) chars)")
                continue
            }
            attempt = 0
            switch event {
            case .nothing: onStatus(.nothing)
            case .playing(let nowPlaying): onStatus(.playing(nowPlaying))
            }
        }
    }

    private func didTerminate(status: Int32) {
        cleanUp()
        guard !stopped else { return }
        onStatus(.unavailable)
        let delay = Backoff.delay(attempt: attempt)
        attempt += 1
        Self.logger.info("Media helper exited (\(status)); restarting in \(delay)s")
        restartTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self, !self.stopped else { return }
            self.launch()
        }
    }

    private func cleanUp() {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        process = nil
        inputPipe = nil
        outputPipe = nil
        buffer.removeAll()
    }
}
