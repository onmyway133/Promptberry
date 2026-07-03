import Foundation

struct MultilinePrompt: Sendable {
    let message: String
    let placeholder: String
    let validate: (@Sendable (String) -> String?)?

    private enum State {
        case active, submitted, cancelled, error(String)
    }

    func run() throws -> String {
        let terminal = Terminal.shared
        var lines: [String] = []
        var current = ""
        var state: State = .active
        var lineCount = 0

        terminal.enableRawMode()
        terminal.hideCursor()
        defer {
            terminal.showCursor()
            terminal.disableRawMode()
        }

        render(state: state, lines: lines, current: current, lineCount: &lineCount)

        while true {
            let key = terminal.readKey()
            switch key {
            case .ctrlC, .escape:
                state = .cancelled
                render(state: state, lines: lines, current: current, lineCount: &lineCount)
                throw PromptCancelled(prompt: message)

            case .ctrlD:
                // Collect all non-empty content lines plus current, trim trailing empties
                var all = lines + [current]
                while all.last == "" { all.removeLast() }
                let joined = all.joined(separator: "\n")
                if let err = validate?(joined) {
                    state = .error(err)
                    render(state: state, lines: lines, current: current, lineCount: &lineCount)
                    continue
                }
                state = .submitted
                render(state: state, lines: lines, current: current, lineCount: &lineCount)
                return joined

            case .enter:
                lines.append(current)
                current = ""
                state = .active
                render(state: state, lines: lines, current: current, lineCount: &lineCount)

            case .backspace:
                if !current.isEmpty {
                    current.removeLast()
                    state = .active
                    render(state: state, lines: lines, current: current, lineCount: &lineCount)
                } else if !lines.isEmpty {
                    current = lines.removeLast()
                    state = .active
                    render(state: state, lines: lines, current: current, lineCount: &lineCount)
                }

            case .space:
                current.append(" ")
                state = .active
                render(state: state, lines: lines, current: current, lineCount: &lineCount)

            case .char(let c):
                current.append(c)
                state = .active
                render(state: state, lines: lines, current: current, lineCount: &lineCount)

            case .paste(let text):
                // Pasted newlines become line breaks, not submissions.
                let parts = text.strippingControlCharacters
                    .split(separator: "\n", omittingEmptySubsequences: false)
                for (index, part) in parts.enumerated() {
                    if index > 0 {
                        lines.append(current)
                        current = ""
                    }
                    current += part
                }
                state = .active
                render(state: state, lines: lines, current: current, lineCount: &lineCount)

            default:
                continue
            }
        }
    }

    private func render(
        state: State,
        lines: [String],
        current: String,
        lineCount: inout Int
    ) {
        let terminal = Terminal.shared
        terminal.clearLines(lineCount)

        var output: [String] = []

        switch state {
        case .active:
            output.append("\(Symbols.active.cyan)  \(message.bold)")
            // Previously committed lines
            for line in lines {
                output.append("\(Symbols.bar.gray)  \(Symbols.cursor.cyan) \(line)")
            }
            // Current line being typed
            if current.isEmpty && lines.isEmpty {
                let hint = placeholder.isEmpty ? "" : placeholder.dim
                output.append("\(Symbols.bar.gray)  \(Symbols.cursor.cyan) \(hint)")
            } else {
                output.append("\(Symbols.bar.gray)  \(Symbols.cursor.cyan) \(current)")
            }
            // Empty line spacer + hint bar
            output.append(Symbols.bar.gray)
            output.append("\(Symbols.barEnd.gray)  \("Ctrl+D to submit".dim)")

        case .error(let msg):
            output.append("\(Symbols.active.cyan)  \(message.bold)")
            for line in lines {
                output.append("\(Symbols.bar.gray)  \(Symbols.cursor.cyan) \(line)")
            }
            output.append("\(Symbols.bar.gray)  \(Symbols.cursor.cyan) \(current)")
            output.append(Symbols.bar.gray)
            output.append("\(Symbols.error.yellow)  \(msg.yellow)")

        case .submitted:
            output.append("\(Symbols.submitted.gray)  \(message.dim)")
            // Show all committed lines (current has already been folded into lines before render)
            for line in lines {
                output.append("\(Symbols.bar.gray)  \(line.dim)")
            }
            if !current.isEmpty {
                output.append("\(Symbols.bar.gray)  \(current.dim)")
            }
            output.append(Symbols.bar.gray)

        case .cancelled:
            output.append("\(Symbols.cancelled.red)  \(message.dim)")
        }

        for line in output { terminal.writeLine(line) }
        lineCount = output.count
    }
}
