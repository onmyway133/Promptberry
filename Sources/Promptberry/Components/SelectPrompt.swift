import Foundation

/// An option for `select` and `multiselect` prompts.
public struct SelectOption<Value: Sendable>: Sendable {
    public let value: Value
    public let label: String
    public let hint: String?

    public init(value: Value, label: String, hint: String? = nil) {
        self.value = value
        self.label = label
        self.hint = hint
    }
}

struct SelectPrompt<Value: Sendable>: Sendable {
    let message: String
    let options: [SelectOption<Value>]
    let initialValue: Value?
    let maxVisible: Int

    private enum State {
        case active, submitted(Int), cancelled
    }

    func run() throws -> Value {
        let terminal = Terminal.shared
        var cursor = initialIndex()
        var state: State = .active
        var lineCount = 0

        terminal.enableRawMode()
        terminal.hideCursor()
        defer {
            terminal.showCursor()
            terminal.disableRawMode()
        }

        render(state: state, cursor: cursor, lineCount: &lineCount)

        while true {
            let key = terminal.readKey()
            switch key {
            case .ctrlC, .escape:
                state = .cancelled
                render(state: state, cursor: cursor, lineCount: &lineCount)
                throw PromptCancelled(prompt: message)

            case .upArrow, .char("k"):
                if cursor > 0 { cursor -= 1 }
                render(state: state, cursor: cursor, lineCount: &lineCount)

            case .downArrow, .char("j"):
                if cursor < options.count - 1 { cursor += 1 }
                render(state: state, cursor: cursor, lineCount: &lineCount)

            case .enter:
                state = .submitted(cursor)
                render(state: state, cursor: cursor, lineCount: &lineCount)
                return options[cursor].value

            default:
                continue
            }
        }
    }

    private func initialIndex() -> Int { 0 }

    /// Compute the visible window of options, keeping cursor centered.
    func visibleRange(cursor: Int) -> Range<Int> {
        let total = options.count
        guard total > maxVisible else { return 0..<total }
        let half = maxVisible / 2
        var start = max(0, cursor - half)
        let end = min(total, start + maxVisible)
        if end - start < maxVisible { start = max(0, end - maxVisible) }
        return start..<end
    }

    private func render(state: State, cursor: Int, lineCount: inout Int) {
        let terminal = Terminal.shared
        terminal.clearLines(lineCount)

        var lines: [String] = []

        switch state {
        case .active:
            lines.append("\(Symbols.active.cyan)  \(message.bold)")

            let range = visibleRange(cursor: cursor)

            if range.lowerBound > 0 {
                lines.append("\(Symbols.bar.gray)  \("↑ \(range.lowerBound) more".dim)")
            }

            for i in range {
                let opt = options[i]
                let hint = opt.hint.map { "  \($0.dim)" } ?? ""
                if i == cursor {
                    let row = "\(Symbols.bar.gray)  \(Symbols.pointer.cyan) \(Symbols.selected.cyan) \(opt.label.cyan)\(hint)"
                    lines.append(row)
                } else {
                    let row = "\(Symbols.bar.gray)    \(Symbols.unselected.dim) \(opt.label.dim)\(hint)"
                    lines.append(row)
                }
            }

            let remaining = options.count - range.upperBound
            if remaining > 0 {
                lines.append("\(Symbols.bar.gray)  \("↓ \(remaining) more".dim)")
            }

            lines.append(Symbols.barEnd.gray)

        case .submitted(let idx):
            lines.append("\(Symbols.submitted.gray)  \(message.dim)")
            lines.append("\(Symbols.bar.gray)  \(options[idx].label.dim)")
            lines.append(Symbols.bar.gray)

        case .cancelled:
            lines.append("\(Symbols.cancelled.red)  \(message.dim)")
        }

        for line in lines { terminal.writeLine(line) }
        lineCount = lines.count
    }
}
