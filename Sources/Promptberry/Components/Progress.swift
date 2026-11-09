import Foundation

/// A progress bar for known-length operations. Updates in place on a single line.
///
/// Usage:
/// ```swift
/// let p = Promptberry.progress(total: 100, message: "Installing...")
/// for i in 0..<100 {
///     await p.advance()
///     try await Task.sleep(nanoseconds: 10_000_000)
/// }
/// await p.complete("All installed!")
/// ```
public actor Progress {

    private let total: Int
    private var current: Int
    private var message: String
    private var isFinished: Bool

    // MARK: - Init

    public init(total: Int, message: String = "") {
        self.total = max(1, total)
        self.current = 0
        self.message = message
        self.isFinished = false
        Terminal.shared.hideCursor()
        Progress.renderStatic(current: 0, total: max(1, total), message: message)
    }

    // MARK: - Public API

    /// Increment the progress by 1, optionally updating the message.
    public func advance(message: String? = nil) {
        guard !isFinished else { return }
        current = min(current + 1, total)
        if let message { self.message = message }
        render()
    }

    /// Set the progress to an absolute value, optionally updating the message.
    public func update(_ value: Int, message: String? = nil) {
        guard !isFinished else { return }
        current = max(0, min(value, total))
        if let message { self.message = message }
        render()
    }

    /// Finish at 100% and print a success line.
    public func complete(message: String = "") {
        guard !isFinished else { return }
        isFinished = true
        current = total
        Terminal.shared.clearLine()
        Terminal.shared.showCursor()
        if !message.isEmpty {
            Terminal.shared.writeLine("\(Symbols.submitted.cyan)  \(message)")
        }
    }

    /// Abort with error styling.
    public func error(message: String = "") {
        guard !isFinished else { return }
        isFinished = true
        Terminal.shared.clearLine()
        Terminal.shared.showCursor()
        if !message.isEmpty {
            Terminal.shared.writeLine("\(Symbols.cancelled.red)  \(message)")
        }
    }

    // MARK: - Rendering

    private func render() {
        Progress.renderStatic(current: current, total: total, message: message)
    }

    private static func renderStatic(current: Int, total: Int, message: String) {
        let t = Terminal.shared
        let clamped = max(0.0, min(1.0, Double(current) / Double(total)))

        // "│  [" + "]" + "  100%" is 11 columns, plus "  message". Keep one
        // spare column: a line that wraps breaks the "\r" redraw and every
        // update then lands on a new line.
        let suffixWidth = message.isEmpty ? 0 : message.count + 2
        let availableWidth = t.width - 12 - suffixWidth
        let barWidth = max(4, min(40, availableWidth))

        let filled = Int(Double(barWidth) * clamped)
        let empty = barWidth - filled

        let filledStr: String
        let emptyStr: String
        if Symbols.supportsUnicode {
            filledStr = String(repeating: "█", count: filled)
            emptyStr  = String(repeating: "░", count: empty)
        } else {
            filledStr = String(repeating: "#", count: filled)
            emptyStr  = String(repeating: "-", count: empty)
        }

        let bar = "[\(filledStr.cyan)\(emptyStr.dim)]"
        let pct = "\(Int(clamped * 100))%"
        let suffix = message.isEmpty ? "" : "  \(message)"
        let line = "\r\(Symbols.bar.gray)  \(bar)  \(pct)\(suffix)"
        t.write(line)
    }
}

// MARK: - Promptberry factory
