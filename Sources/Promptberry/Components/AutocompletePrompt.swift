import Foundation

struct AutocompletePrompt<Value: Sendable>: Sendable {
    let message: String
    let options: [SelectOption<Value>]
    let placeholder: String
    let maxVisible: Int

    private enum State {
        case active, submitted(String), cancelled, error(String)
    }

    func run() throws -> Value {
        let terminal = Terminal.shared
        var input: String = ""
        var highlightCursor: Int = -1   // index into `filtered`; -1 = none highlighted
        var filtered: [SelectOption<Value>] = options
        var state: State = .active
        var lineCount = 0

        terminal.enableRawMode()
        terminal.hideCursor()
        defer {
            terminal.showCursor()
            terminal.disableRawMode()
        }

        render(state: state, input: input, filtered: filtered, highlightCursor: highlightCursor, lineCount: &lineCount)

        while true {
            let key = terminal.readKey()
            switch key {

            // ── Cancel ────────────────────────────────────────────────────
            case .ctrlC, .escape:
                state = .cancelled
                render(state: state, input: input, filtered: filtered, highlightCursor: highlightCursor, lineCount: &lineCount)
                throw PromptCancelled(prompt: message)

            // ── Navigate highlight up ─────────────────────────────────────
            case .upArrow:
                if !filtered.isEmpty {
                    if highlightCursor <= 0 {
                        highlightCursor = filtered.count - 1
                    } else {
                        highlightCursor -= 1
                    }
                }
                render(state: state, input: input, filtered: filtered, highlightCursor: highlightCursor, lineCount: &lineCount)

            // ── Navigate highlight down ───────────────────────────────────
            case .downArrow:
                if !filtered.isEmpty {
                    if highlightCursor >= filtered.count - 1 {
                        highlightCursor = 0
                    } else {
                        highlightCursor += 1
                    }
                }
                render(state: state, input: input, filtered: filtered, highlightCursor: highlightCursor, lineCount: &lineCount)

            // ── Tab: autocomplete from highlighted match ───────────────────
            case .tab:
                if highlightCursor >= 0 && highlightCursor < filtered.count {
                    input = filtered[highlightCursor].label
                    highlightCursor = -1
                    filtered = applyFilter(input: input)
                    state = .active
                    render(state: state, input: input, filtered: filtered, highlightCursor: highlightCursor, lineCount: &lineCount)
                }

            // ── Enter: submit ─────────────────────────────────────────────
            case .enter:
                // Priority 1: a highlighted match is explicitly chosen
                if highlightCursor >= 0 && highlightCursor < filtered.count {
                    let chosen = filtered[highlightCursor]
                    state = .submitted(chosen.label)
                    render(state: state, input: input, filtered: filtered, highlightCursor: highlightCursor, lineCount: &lineCount)
                    return chosen.value
                }

                // Priority 2: exactly one filtered match — accept it implicitly
                if filtered.count == 1 {
                    let chosen = filtered[0]
                    state = .submitted(chosen.label)
                    render(state: state, input: input, filtered: filtered, highlightCursor: highlightCursor, lineCount: &lineCount)
                    return chosen.value
                }

                // Priority 3: input matches a label exactly (case-insensitive)
                if let exact = options.first(where: { $0.label.localizedCaseInsensitiveCompare(input) == .orderedSame }) {
                    state = .submitted(exact.label)
                    render(state: state, input: input, filtered: filtered, highlightCursor: highlightCursor, lineCount: &lineCount)
                    return exact.value
                }

                // Nothing matched
                state = .error("No match found. Type to filter or use ↑ ↓ to navigate.")
                render(state: state, input: input, filtered: filtered, highlightCursor: highlightCursor, lineCount: &lineCount)

            // ── Backspace ─────────────────────────────────────────────────
            case .backspace:
                if !input.isEmpty {
                    input.removeLast()
                    filtered = applyFilter(input: input)
                    // Keep highlight in bounds after filter changes
                    if filtered.isEmpty {
                        highlightCursor = -1
                    } else if highlightCursor >= filtered.count {
                        highlightCursor = filtered.count - 1
                    }
                    state = .active
                    render(state: state, input: input, filtered: filtered, highlightCursor: highlightCursor, lineCount: &lineCount)
                }

            // ── Regular character ─────────────────────────────────────────
            case .space:
                input.append(" ")
                filtered = applyFilter(input: input)
                highlightCursor = -1
                state = .active
                render(state: state, input: input, filtered: filtered, highlightCursor: highlightCursor, lineCount: &lineCount)

            case .char(let c):
                input.append(c)
                filtered = applyFilter(input: input)
                // Reset highlight when the filtered set changes due to typing
                highlightCursor = -1
                state = .active
                render(state: state, input: input, filtered: filtered, highlightCursor: highlightCursor, lineCount: &lineCount)

            default:
                continue
            }
        }
    }

    // MARK: - Filtering

    private func applyFilter(input: String) -> [SelectOption<Value>] {
        guard !input.isEmpty else { return options }
        return options.filter { $0.label.localizedCaseInsensitiveContains(input) }
    }

    // MARK: - Visible window (mirrors SelectPrompt)

    private func visibleRange(highlightCursor: Int, total: Int) -> Range<Int> {
        guard total > maxVisible else { return 0..<total }
        let effectiveCursor = max(0, highlightCursor)
        let half = maxVisible / 2
        var start = max(0, effectiveCursor - half)
        let end = min(total, start + maxVisible)
        if end - start < maxVisible { start = max(0, end - maxVisible) }
        return start..<end
    }

    // MARK: - Render

    private func render(
        state: State,
        input: String,
        filtered: [SelectOption<Value>],
        highlightCursor: Int,
        lineCount: inout Int
    ) {
        let terminal = Terminal.shared
        terminal.clearLines(lineCount)

        var lines: [String] = []

        switch state {
        case .active, .error:
            // Header
            lines.append("\(Symbols.active.cyan)  \(message.bold)")

            // Input line
            if input.isEmpty {
                let hint = placeholder.isEmpty ? "" : "  \(placeholder.dim)"
                lines.append("\(Symbols.bar.gray)  \(Symbols.cursor.cyan)\(hint)")
            } else {
                lines.append("\(Symbols.bar.gray)  \(Symbols.cursor.cyan) \(input)")
            }

            // Filtered options list
            if !filtered.isEmpty {
                let range = visibleRange(highlightCursor: highlightCursor, total: filtered.count)

                if range.lowerBound > 0 {
                    lines.append("\(Symbols.bar.gray)  \("↑ \(range.lowerBound) more".dim)")
                }

                for i in range {
                    let opt = filtered[i]
                    let hint = opt.hint.map { "  \($0.dim)" } ?? ""
                    if i == highlightCursor {
                        lines.append("\(Symbols.bar.gray)  \(Symbols.pointer.cyan) \(Symbols.selected.cyan) \(opt.label.cyan)\(hint)")
                    } else {
                        lines.append("\(Symbols.bar.gray)    \(Symbols.unselected.dim) \(opt.label.dim)\(hint)")
                    }
                }

                let remaining = filtered.count - range.upperBound
                if remaining > 0 {
                    lines.append("\(Symbols.bar.gray)  \("↓ \(remaining) more".dim)")
                }
            }

            if case .error(let msg) = state {
                lines.append("\(Symbols.error.yellow)  \(msg.yellow)")
            } else {
                lines.append(Symbols.barEnd.gray)
            }

        case .submitted(let label):
            lines.append("\(Symbols.submitted.gray)  \(message.dim)")
            lines.append("\(Symbols.bar.gray)  \(label.dim)")
            lines.append(Symbols.bar.gray)

        case .cancelled:
            lines.append("\(Symbols.cancelled.red)  \(message.dim)")
        }

        for line in lines { terminal.writeLine(line) }
        lineCount = lines.count
    }
}
