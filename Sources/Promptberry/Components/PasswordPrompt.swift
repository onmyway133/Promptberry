import Foundation

struct PasswordPrompt: Sendable {
    let message: String
    let mask: Character

    private enum State {
        case active, submitted(Int), cancelled
    }

    func run() throws -> String {
        let terminal = Terminal.shared
        var actual = ""
        var state: State = .active
        var lineCount = 0

        terminal.enableRawMode()
        terminal.hideCursor()
        defer {
            terminal.showCursor()
            terminal.disableRawMode()
        }

        render(state: state, maskedCount: 0, lineCount: &lineCount)

        while true {
            let key = terminal.readKey()
            switch key {
            case .ctrlC, .escape:
                state = .cancelled
                render(state: state, maskedCount: actual.count, lineCount: &lineCount)
                throw PromptCancelled(prompt: message)

            case .enter:
                state = .submitted(actual.count)
                render(state: state, maskedCount: actual.count, lineCount: &lineCount)
                return actual

            case .backspace:
                if !actual.isEmpty { actual.removeLast() }
                render(state: state, maskedCount: actual.count, lineCount: &lineCount)

            case .char(let c):
                actual.append(c)
                render(state: state, maskedCount: actual.count, lineCount: &lineCount)

            default:
                continue
            }
        }
    }

    private func render(state: State, maskedCount: Int, lineCount: inout Int) {
        let terminal = Terminal.shared
        terminal.clearLines(lineCount)

        let masked = String(repeating: mask, count: maskedCount)
        var lines: [String] = []

        switch state {
        case .active:
            lines.append("\(Symbols.active.cyan)  \(message.bold)")
            lines.append("\(Symbols.bar.gray)  \(Symbols.cursor.cyan) \(masked.dim)")
            lines.append(Symbols.barEnd.gray)

        case .submitted(let count):
            lines.append("\(Symbols.submitted.gray)  \(message.dim)")
            lines.append("\(Symbols.bar.gray)  \(String(repeating: mask, count: count).dim)")

        case .cancelled:
            lines.append("\(Symbols.cancelled.red)  \(message.dim)")
        }

        for line in lines { terminal.writeLine(line) }
        lineCount = lines.count
    }
}
