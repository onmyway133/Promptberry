import Foundation

struct ConfirmPrompt: Sendable {
    let message: String
    let activeLabel: String
    let inactiveLabel: String
    let initialValue: Bool

    private enum State {
        case active, submitted(Bool), cancelled
    }

    func run() throws -> Bool {
        let terminal = Terminal.shared
        var value = initialValue
        var state: State = .active
        var lineCount = 0

        terminal.enableRawMode()
        terminal.hideCursor()
        defer {
            terminal.showCursor()
            terminal.disableRawMode()
        }

        render(state: state, value: value, lineCount: &lineCount)

        while true {
            let key = terminal.readKey()
            switch key {
            case .ctrlC, .escape:
                state = .cancelled
                render(state: state, value: value, lineCount: &lineCount)
                throw PromptCancelled(prompt: message)

            case .enter:
                state = .submitted(value)
                render(state: state, value: value, lineCount: &lineCount)
                return value

            case .leftArrow, .rightArrow, .space:
                value.toggle()
                render(state: state, value: value, lineCount: &lineCount)

            case .char("y"), .char("Y"):
                value = true
                render(state: state, value: value, lineCount: &lineCount)

            case .char("n"), .char("N"):
                value = false
                render(state: state, value: value, lineCount: &lineCount)

            default:
                continue
            }
        }
    }

    private func render(state: State, value: Bool, lineCount: inout Int) {
        let terminal = Terminal.shared
        terminal.clearLines(lineCount)

        var lines: [String] = []

        switch state {
        case .active:
            lines.append("\(Symbols.active.cyan)  \(message.bold)")
            // inactiveLabel stays left, activeLabel stays right — only the dot moves
            let left = value
                ? "\(Symbols.unselected.dim) \(inactiveLabel.dim)"
                : "\(Symbols.selected.cyan) \(inactiveLabel.cyan)"
            let right = value
                ? "\(Symbols.selected.cyan) \(activeLabel.cyan)"
                : "\(Symbols.unselected.dim) \(activeLabel.dim)"
            lines.append("\(Symbols.bar.gray)  \(left)  /  \(right)")
            lines.append(Symbols.barEnd.gray)

        case .submitted(let v):
            lines.append("\(Symbols.submitted.gray)  \(message.dim)")
            lines.append("\(Symbols.bar.gray)  \((v ? activeLabel : inactiveLabel).dim)")
            lines.append(Symbols.bar.gray)

        case .cancelled:
            lines.append("\(Symbols.cancelled.red)  \(message.dim)")
        }

        for line in lines { terminal.writeLine(line) }
        lineCount = lines.count
    }
}
