import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
@preconcurrency import Glibc
#elseif canImport(Musl)
import Musl
#else
#error("Unsupported runtime")
#endif

// MARK: - Key

public enum Key: Sendable {
    case char(Character)
    case upArrow, downArrow, leftArrow, rightArrow
    case enter, backspace, delete
    case space, tab, escape
    case ctrlC, ctrlD, ctrlA, ctrlE
    case home, end
    case pageUp, pageDown
    case unknown([UInt8])
}

// MARK: - Terminal

public final class Terminal: @unchecked Sendable {

    public static let shared = Terminal()

    private var originalTermios = termios()
    private var rawModeActive = false

    private init() {
        atexit { Terminal.shared.restoreIfNeeded() }
    }

    // MARK: - Raw mode

    public func enableRawMode() {
        guard !rawModeActive else { return }
        guard tcgetattr(STDIN_FILENO, &originalTermios) == 0 else { return }

        var raw = originalTermios
        raw.c_lflag &= ~tcflag_t(ICANON | ECHO | ECHOE | ECHOK | ECHONL | IEXTEN | ISIG)
        raw.c_iflag &= ~tcflag_t(IXON | ICRNL | INPCK | ISTRIP | BRKINT)
        raw.c_oflag &= ~tcflag_t(OPOST)
        raw.c_cflag |= tcflag_t(CS8)

        // Set VMIN=1 (read at least 1 byte), VTIME=0 (no timeout)
        // c_cc is a fixed-size tuple; use withUnsafeMutableBytes for indexed access
        withUnsafeMutableBytes(of: &raw.c_cc) { ptr in
            ptr[Int(VMIN)]  = 1
            ptr[Int(VTIME)] = 0
        }

        tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw)
        rawModeActive = true
    }

    public func disableRawMode() {
        guard rawModeActive else { return }
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &originalTermios)
        rawModeActive = false
    }

    func restoreIfNeeded() {
        if rawModeActive {
            tcsetattr(STDIN_FILENO, TCSAFLUSH, &originalTermios)
        }
    }

    // MARK: - Output

    public func write(_ s: String) {
        // Empty Data has a nil baseAddress. Skip instead of force-unwrapping.
        guard let data = s.data(using: .utf8), !data.isEmpty else { return }
        data.withUnsafeBytes { ptr in
            #if canImport(Darwin)
            _ = Darwin.write(STDOUT_FILENO, ptr.baseAddress!, ptr.count)
            #elseif canImport(Glibc)
            _ = Glibc.write(STDOUT_FILENO, ptr.baseAddress!, ptr.count)
            #elseif canImport(Musl)
            _ = Musl.write(STDOUT_FILENO, ptr.baseAddress!, ptr.count)
            #else
            #error("Unsupported platform: Terminal.write requires Darwin, Glibc, or Musl")
            #endif
        }
    }

    public func writeLine(_ s: String) {
        write(s + "\r\n")
    }

    /// Move cursor up N lines, erasing each line — the core redraw primitive.
    public func clearLines(_ n: Int) {
        guard n > 0 else { return }
        for _ in 0..<n {
            write("\u{1B}[1A")  // cursor up 1
            write("\u{1B}[2K")  // erase entire line
        }
        write("\r")
    }

    public func clearLine() {
        write("\r\u{1B}[2K")
    }

    public func hideCursor() { write("\u{1B}[?25l") }
    public func showCursor() { write("\u{1B}[?25h") }

    // MARK: - Terminal size

    public var width: Int {
        var ws = winsize()
        #if canImport(Musl)
        // The Static Linux SDK marks variadic ioctl unavailable in its Musl
        // module; tcgetwinsize is musl's direct non-variadic equivalent.
        let result = tcgetwinsize(STDOUT_FILENO, &ws)
        #else
        let result = ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &ws)
        #endif
        if result == 0, ws.ws_col > 0 {
            return Int(ws.ws_col)
        }
        return 80
    }

    public var height: Int {
        var ws = winsize()
        #if canImport(Musl)
        let result = tcgetwinsize(STDOUT_FILENO, &ws)
        #else
        let result = ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &ws)
        #endif
        if result == 0, ws.ws_row > 0 {
            return Int(ws.ws_row)
        }
        return 24
    }

    public var isInteractive: Bool { isatty(STDIN_FILENO) != 0 }

    // MARK: - Input

    /// Blocking read of the next key press.
    /// Safe to call from an async Task — blocks the OS thread, not the cooperative pool.
    public func readKey() -> Key {
        var buf = [UInt8](repeating: 0, count: 8)
        #if canImport(Darwin)
        let n = Darwin.read(STDIN_FILENO, &buf, 8)
        #elseif canImport(Glibc)
        let n = Glibc.read(STDIN_FILENO, &buf, 8)
        #elseif canImport(Musl)
        let n = Musl.read(STDIN_FILENO, &buf, 8)
        #else
        #error("Unsupported platform: Terminal.readKey requires Darwin, Glibc, or Musl")
        #endif
        guard n > 0 else { return .unknown([]) }

        switch buf[0] {
        case 3:   return .ctrlC
        case 4:   return .ctrlD
        case 1:   return .ctrlA
        case 5:   return .ctrlE
        case 13:  return .enter
        case 127: return .backspace
        case 9:   return .tab
        case 32:  return .space

        case 27:  // ESC or escape sequence
            guard n >= 3 else { return .escape }
            if buf[1] == 91 {  // CSI: ESC [
                switch buf[2] {
                case 65: return .upArrow
                case 66: return .downArrow
                case 67: return .rightArrow
                case 68: return .leftArrow
                case 72: return .home
                case 70: return .end
                case 51: return n >= 4 && buf[3] == 126 ? .delete : .unknown(Array(buf[0..<n]))
                case 53: return n >= 4 && buf[3] == 126 ? .pageUp : .unknown(Array(buf[0..<n]))
                case 54: return n >= 4 && buf[3] == 126 ? .pageDown : .unknown(Array(buf[0..<n]))
                default: return .unknown(Array(buf[0..<n]))
                }
            }
            if buf[1] == 79 {  // SS3: ESC O
                switch buf[2] {
                case 72: return .home
                case 70: return .end
                default: return .unknown(Array(buf[0..<n]))
                }
            }
            return .escape

        default:
            let bytes = Array(buf[0..<n])
            if let s = String(bytes: bytes, encoding: .utf8), let scalar = s.unicodeScalars.first {
                return .char(Character(scalar))
            }
            return .unknown(bytes)
        }
    }
}
