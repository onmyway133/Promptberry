import Foundation

/// Animated spinner for async operations.
///
/// Usage:
/// ```swift
/// let s = Promptberry.spinner()
/// await s.start("Installing...")
/// try await doWork()
/// await s.stop("Done!")
/// ```
public actor Spinner {

    private var animationTask: Task<Void, Never>?
    private var message: String = ""
    private var frameIndex: Int = 0
    private let frames: [String]

    init() {
        frames = Symbols.frames
    }

    // MARK: - Public API

    public func start(_ message: String = "") {
        self.message = message
        self.frameIndex = 0
        Terminal.shared.hideCursor()
        animationTask?.cancel()
        animationTask = Task { [frames] in
            var idx = 0
            while !Task.isCancelled {
                let frame = frames[idx % frames.count]
                let line = "\r\(frame.cyan)  \(self.message)"
                Terminal.shared.write(line)
                idx += 1
                try? await Task.sleep(nanoseconds: 80_000_000)  // 80ms ≈ 12 fps
            }
        }
    }

    /// Update the spinner message while it's running.
    public func update(_ newMessage: String) {
        message = newMessage
    }

    public func stop(_ message: String = "") {
        finish(symbol: Symbols.submitted.cyan, message: message)
    }

    public func error(_ message: String = "") {
        finish(symbol: Symbols.cancelled.red, message: message)
    }

    public func warning(_ message: String = "") {
        finish(symbol: Symbols.error.yellow, message: message)
    }

    // MARK: - Private

    private func finish(symbol: String, message: String) {
        animationTask?.cancel()
        animationTask = nil
        Terminal.shared.clearLine()
        Terminal.shared.showCursor()
        if !message.isEmpty {
            Terminal.shared.writeLine("\(symbol)  \(message)")
        }
    }
}
