import Foundation

struct TextPrompt: Sendable {
    let message: String
    let placeholder: String
    let defaultValue: String?
    let validate: (@Sendable (String) -> String?)?

    private enum State {
        case active, submitted(String), cancelled, error(String)
    }

    func run() throws -> String {
        let terminal = Terminal.shared
        var input = ""
        var state: State = .active
        var lineCount = 0

        terminal.enableRawMode()
        terminal.hideCursor()
        defer {
            terminal.showCursor()
            terminal.disableRawMode()
        }

        render(state: state, input: input, lineCount: &lineCount)

        while true {
            let key = terminal.readKey()
            switch key {
            case .ctrlC, .escape:
                state = .cancelled
                render(state: state, input: input, lineCount: &lineCount)
                throw PromptCancelled(prompt: message)

            case .enter:
                let value = input.isEmpty ? (defaultValue ?? "") : input
                if let err = validate?(value) {
                    state = .error(err)
                    render(state: state, input: input, lineCount: &lineCount)
                    continue
                }
                state = .submitted(value)
                render(state: state, input: input, lineCount: &lineCount)
                return value

            case .backspace:
                if !input.isEmpty { input.removeLast() }
                state = .active
                render(state: state, input: input, lineCount: &lineCount)

            case .char(let c):
                input.append(c)
                state = .active
                render(state: state, input: input, lineCount: &lineCount)

            default:
                continue
            }
        }
    }

    private func render(state: State, input: String, lineCount: inout Int) {
        let terminal = Terminal.shared
        terminal.clearLines(lineCount)

        var lines: [String] = []

        switch state {
        case .active:
            lines.append("\(Symbols.active.cyan)  \(message.bold)")
            if input.isEmpty {
                let hint = placeholder.isEmpty ? "" : placeholder.dim
                lines.append("\(Symbols.bar.gray)  \(Symbols.cursor.cyan) \(hint)")
            } else {
                lines.append("\(Symbols.bar.gray)  \(Symbols.cursor.cyan) \(input)")
            }
            lines.append(Symbols.barEnd.gray)

        case .error(let msg):
            lines.append("\(Symbols.active.cyan)  \(message.bold)")
            lines.append("\(Symbols.bar.gray)  \(Symbols.cursor.cyan) \(input)")
            lines.append("\(Symbols.error.yellow)  \(msg.yellow)")

        case .submitted(let value):
            lines.append("\(Symbols.submitted.gray)  \(message.dim)")
            lines.append("\(Symbols.bar.gray)  \(value.dim)")

        case .cancelled:
            lines.append("\(Symbols.cancelled.red)  \(message.dim)")
        }

        for line in lines { terminal.writeLine(line) }
        lineCount = lines.count
    }
}
