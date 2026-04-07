import Foundation

public enum Symbols {

    // MARK: - Unicode detection

    static let supportsUnicode: Bool = {
        let env = ProcessInfo.processInfo.environment
        let lang = env["LANG"] ?? env["LC_ALL"] ?? env["LC_CTYPE"] ?? ""
        return lang.uppercased().contains("UTF")
    }()

    // MARK: - Prompt state

    public static var active: String     { supportsUnicode ? "◆" : "*" }
    public static var submitted: String  { supportsUnicode ? "◇" : "o" }
    public static var cancelled: String  { supportsUnicode ? "■" : "x" }
    public static var error: String      { supportsUnicode ? "▲" : "!" }

    // MARK: - Box drawing

    public static var bar: String        { supportsUnicode ? "│" : "|" }
    public static var topLeft: String    { supportsUnicode ? "┌" : "+" }
    public static var bottomLeft: String { supportsUnicode ? "└" : "+" }
    public static var dash: String       { supportsUnicode ? "─" : "-" }
    public static var barEnd: String     { supportsUnicode ? "└" : "+" }

    // MARK: - Selection

    public static var selected: String   { supportsUnicode ? "●" : "(*)" }
    public static var unselected: String { supportsUnicode ? "○" : "( )" }
    public static var checkbox: String   { supportsUnicode ? "◼" : "[x]" }
    public static var uncheckbox: String { supportsUnicode ? "◻" : "[ ]" }
    public static var pointer: String    { supportsUnicode ? "›" : ">" }
    public static var cursor: String     { supportsUnicode ? "▌" : "|" }

    // MARK: - Log

    public static var info: String       { supportsUnicode ? "●" : "i" }
    public static var success: String    { supportsUnicode ? "◆" : "v" }
    public static var warning: String    { supportsUnicode ? "▲" : "!" }
    public static var step: String       { supportsUnicode ? "◆" : "-" }

    // MARK: - Spinner frames

    public static let spinnerFrames: [String] = ["⠋","⠙","⠹","⠸","⠼","⠴","⠦","⠧","⠇","⠏"]
    public static let spinnerFramesASCII: [String] = ["-","\\","|","/"]

    public static var frames: [String] { supportsUnicode ? spinnerFrames : spinnerFramesASCII }
}
