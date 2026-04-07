import Darwin
import Foundation

// MARK: - Color support detection (Rainbow-inspired)

public enum ColorSupport: Sendable {
    case full    // ANSI colors supported
    case none    // No color (piped, dumb terminal, NO_COLOR)

    static let current: ColorSupport = {
        let env = ProcessInfo.processInfo.environment
        // FORCE_COLOR wins first
        if env["FORCE_COLOR"] != nil { return .full }
        // NO_COLOR spec: https://no-color.org
        if env["NO_COLOR"] != nil { return .none }
        // Must be a TTY
        guard isatty(STDOUT_FILENO) != 0 else { return .none }
        // Dumb terminal
        if env["TERM"] == "dumb" { return .none }
        return .full
    }()

    public static var enabled: Bool {
        get { _enabled ?? (current == .full) }
        set { _enabled = newValue }
    }
    nonisolated(unsafe) private static var _enabled: Bool? = nil
}

// MARK: - Named color enum

public enum NamedColor: Int {
    case black = 30, red, green, yellow, blue, magenta, cyan, white
    case default_ = 39
    case brightBlack = 90, brightRed, brightGreen, brightYellow
    case brightBlue, brightMagenta, brightCyan, brightWhite

    var code: Int { rawValue }
    var bgCode: Int { rawValue + 10 }
}

// MARK: - Style enum

public enum Style: Int {
    case bold = 1, dim, italic, underline, blink, swap = 7, strikethrough = 9
    var code: Int { rawValue }
}

// MARK: - String extension — Rainbow-style fluent chaining

extension String {
    // MARK: Foreground colors
    public var black: String        { colorize(.black) }
    public var red: String          { colorize(.red) }
    public var green: String        { colorize(.green) }
    public var yellow: String       { colorize(.yellow) }
    public var blue: String         { colorize(.blue) }
    public var magenta: String      { colorize(.magenta) }
    public var cyan: String         { colorize(.cyan) }
    public var white: String        { colorize(.white) }
    public var gray: String         { colorize(.brightBlack) }  // bright black = gray

    // MARK: Background colors
    public var onBlack: String      { bgColorize(.black) }
    public var onRed: String        { bgColorize(.red) }
    public var onGreen: String      { bgColorize(.green) }
    public var onYellow: String     { bgColorize(.yellow) }
    public var onBlue: String       { bgColorize(.blue) }
    public var onCyan: String       { bgColorize(.cyan) }
    public var onWhite: String      { bgColorize(.white) }

    // MARK: Styles
    public var bold: String         { stylize(.bold) }
    public var dim: String          { stylize(.dim) }
    public var italic: String       { stylize(.italic) }
    public var underline: String    { stylize(.underline) }
    public var blink: String        { stylize(.blink) }
    public var strikethrough: String { stylize(.strikethrough) }

    // MARK: Raw (strip ANSI codes) — matches Rainbow's .raw
    public var raw: String {
        var result = ""
        var i = startIndex
        while i < endIndex {
            if self[i] == "\u{1B}", let ni = index(i, offsetBy: 1, limitedBy: endIndex), ni < endIndex, self[ni] == "[" {
                var j = index(ni, offsetBy: 1, limitedBy: endIndex) ?? endIndex
                while j < endIndex && !self[j].isLetter { j = index(after: j) }
                if j < endIndex { j = index(after: j) }
                i = j
            } else {
                result.append(self[i])
                i = index(after: i)
            }
        }
        return result
    }

    // MARK: Internal helpers

    func colorize(_ color: NamedColor) -> String {
        guard ColorSupport.enabled else { return self }
        return "\u{1B}[\(color.code)m\(self)\u{1B}[0m"
    }

    func bgColorize(_ color: NamedColor) -> String {
        guard ColorSupport.enabled else { return self }
        return "\u{1B}[\(color.bgCode)m\(self)\u{1B}[0m"
    }

    func stylize(_ style: Style) -> String {
        guard ColorSupport.enabled else { return self }
        return "\u{1B}[\(style.code)m\(self)\u{1B}[0m"
    }
}

// MARK: - Convenience namespace (for backward compat in library internals)

enum Color {
    static func cyan(_ s: String) -> String    { s.cyan }
    static func gray(_ s: String) -> String    { s.gray }
    static func red(_ s: String) -> String     { s.red }
    static func green(_ s: String) -> String   { s.green }
    static func yellow(_ s: String) -> String  { s.yellow }
    static func blue(_ s: String) -> String    { s.blue }
    static func white(_ s: String) -> String   { s.white }
    static func bold(_ s: String) -> String    { s.bold }
    static func dim(_ s: String) -> String     { s.dim }
}
