/// Semantic log messages — non-interactive, always printed to stdout.
/// Usage: `log.info("message")`, `log.success("message")`, etc.
public enum log {

    public static func info(_ message: String) {
        let t = Terminal.shared
        t.writeLine("\(Symbols.info.blue)  \(message.gray)")
    }

    public static func success(_ message: String) {
        let t = Terminal.shared
        t.writeLine("\(Symbols.success.green)  \(message.gray)")
    }

    public static func warning(_ message: String) {
        let t = Terminal.shared
        t.writeLine("\(Symbols.warning.yellow)  \(message.gray)")
    }

    public static func error(_ message: String) {
        let t = Terminal.shared
        t.writeLine("\(Symbols.cancelled.red)  \(message.gray)")
    }

    public static func step(_ message: String) {
        let t = Terminal.shared
        t.writeLine("\(Symbols.step.cyan)  \(message.gray)")
    }
}
