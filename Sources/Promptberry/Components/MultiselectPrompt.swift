import Foundation

struct MultiselectPrompt<Value: Sendable & Hashable>: Sendable {
    let message: String
    let options: [SelectOption<Value>]
    let initialValues: Set<Value>
    let required: Bool
    let maxVisible: Int

    private enum State {
        case active, submitted, cancelled, error(String)
    }

    func run() throws -> [Value] {
        let terminal = Terminal.shared
        var cursor = 0
        var selected: Set<Int> = initialSelectedIndices()
        var state: State = .active
        var lineCount = 0

        terminal.enableRawMode()
        terminal.hideCursor()
        defer {
            terminal.showCursor()
            terminal.disableRawMode()
        }

        render(state: state, cursor: cursor, selected: selected, lineCount: &lineCount)

        while true {
            let key = terminal.readKey()
            switch key {
            case .ctrlC, .escape:
                state = .cancelled
                render(state: state, cursor: cursor, selected: selected, lineCount: &lineCount)
                throw PromptCancelled(prompt: message)

            case .upArrow, .char("k"):
                if cursor > 0 { cursor -= 1 }
                render(state: state, cursor: cursor, selected: selected, lineCount: &lineCount)

            case .downArrow, .char("j"):
                if cursor < options.count - 1 { cursor += 1 }
                render(state: state, cursor: cursor, selected: selected, lineCount: &lineCount)

            case .space:
                if selected.contains(cursor) {
                    selected.remove(cursor)
                } else {
                    selected.insert(cursor)
                }
                state = .active
                render(state: state, cursor: cursor, selected: selected, lineCount: &lineCount)

            case .char("a"):
                // Toggle all: if all selected → deselect all, else select all
                if selected.count == options.count {
                    selected.removeAll()
                } else {
                    selected = Set(0..<options.count)
                }
                render(state: state, cursor: cursor, selected: selected, lineCount: &lineCount)

            case .enter:
                if required && selected.isEmpty {
                    state = .error("Please select at least one option.")
                    render(state: state, cursor: cursor, selected: selected, lineCount: &lineCount)
                    continue
                }
                state = .submitted
                render(state: state, cursor: cursor, selected: selected, lineCount: &lineCount)
                return selected.sorted().map { options[$0].value }

            default:
                continue
            }
        }
    }

    private func initialSelectedIndices() -> Set<Int> {
        var result = Set<Int>()
        for (i, opt) in options.enumerated() {
            if initialValues.contains(opt.value) { result.insert(i) }
        }
        return result
    }

    private func visibleRange(cursor: Int) -> Range<Int> {
        let total = options.count
        guard total > maxVisible else { return 0..<total }
        let half = maxVisible / 2
        var start = max(0, cursor - half)
        let end = min(total, start + maxVisible)
        if end - start < maxVisible { start = max(0, end - maxVisible) }
        return start..<end
    }

    private func render(state: State, cursor: Int, selected: Set<Int>, lineCount: inout Int) {
        let terminal = Terminal.shared
        terminal.clearLines(lineCount)

        var lines: [String] = []

        switch state {
        case .active, .error:
            lines.append("\(Symbols.active.cyan)  \(message.bold)")

            let range = visibleRange(cursor: cursor)

            if range.lowerBound > 0 {
                lines.append("\(Symbols.bar.gray)  \("↑ \(range.lowerBound) more".dim)")
            }

            for i in range {
                let opt = options[i]
                let isCursor = i == cursor
                let isSelected = selected.contains(i)
                let hint = opt.hint.map { "  \($0.dim)" } ?? ""

                let check: String
                let label: String
                if isCursor && isSelected {
                    check = Symbols.checkbox.cyan
                    label = opt.label.cyan
                } else if isCursor {
                    check = Symbols.uncheckbox.cyan
                    label = opt.label.cyan
                } else if isSelected {
                    check = Symbols.checkbox.green
                    label = opt.label.green
                } else {
                    check = Symbols.uncheckbox.dim
                    label = opt.label.dim
                }

                let pointer = isCursor ? Symbols.pointer.cyan : " "
                lines.append("\(Symbols.bar.gray)  \(pointer) \(check) \(label)\(hint)")
            }

            let remaining = options.count - range.upperBound
            if remaining > 0 {
                lines.append("\(Symbols.bar.gray)  \("↓ \(remaining) more".dim)")
            }

            let hint = "Space to toggle · Enter to confirm · a to toggle all"
            lines.append("\(Symbols.bar.gray)  \(hint.dim)")

            if case .error(let msg) = state {
                lines.append("\(Symbols.error.yellow)  \(msg.yellow)")
            } else {
                lines.append(Symbols.barEnd.gray)
            }

        case .submitted:
            lines.append("\(Symbols.submitted.gray)  \(message.dim)")
            let labels = selected.sorted().map { options[$0].label }.joined(separator: ", ")
            lines.append("\(Symbols.bar.gray)  \(labels.dim)")
            lines.append(Symbols.bar.gray)

        case .cancelled:
            lines.append("\(Symbols.cancelled.red)  \(message.dim)")
        }

        for line in lines { terminal.writeLine(line) }
        lineCount = lines.count
    }
}
