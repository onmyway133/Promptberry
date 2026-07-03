import Darwin
import Foundation

// MARK: - Key

public enum Key: Sendable, Equatable {
    case char(Character)
    case upArrow, downArrow, leftArrow, rightArrow
    case enter, backspace, delete
    case space, tab, escape
    case ctrlC, ctrlD, ctrlA, ctrlE
    case home, end
    case pageUp, pageDown
    /// A bracketed paste: the whole pasted text as one event, newlines
    /// normalized to "\n". Each prompt decides what newlines mean.
    case paste(String)
    case unknown([UInt8])
}

// MARK: - Terminal

public final class Terminal: @unchecked Sendable {

    public static let shared = Terminal()

    private var originalTermios = termios()
    private var rawModeActive = false
    private var pendingKeys: [Key] = []
    /// Bytes read from the tty but not yet parsed into keys — an escape
    /// sequence, UTF-8 character, or bracketed paste can be split across reads.
    private var pendingBytes: [UInt8] = []

    private init() {
        atexit { Terminal.shared.restoreIfNeeded() }
    }

    // MARK: - Raw mode

    public func enableRawMode() {
        guard !rawModeActive else { return }
        pendingKeys.removeAll()
        pendingBytes.removeAll()
        guard tcgetattr(STDIN_FILENO, &originalTermios) == 0 else { return }

        var raw = originalTermios
        raw.c_lflag &= ~UInt(ICANON | ECHO | ECHOE | ECHOK | ECHONL | IEXTEN | ISIG)
        raw.c_iflag &= ~UInt(IXON | ICRNL | INPCK | ISTRIP | BRKINT)
        raw.c_oflag &= ~UInt(OPOST)
        raw.c_cflag |= UInt(CS8)

        // Set VMIN=1 (read at least 1 byte), VTIME=0 (no timeout)
        // c_cc is a fixed-size tuple; use withUnsafeMutableBytes for indexed access
        withUnsafeMutableBytes(of: &raw.c_cc) { ptr in
            ptr[Int(VMIN)]  = 1
            ptr[Int(VTIME)] = 0
        }

        tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw)
        rawModeActive = true

        // Bracketed paste: the terminal wraps pastes in ESC[200~ … ESC[201~,
        // so pasted text arrives as one .paste event instead of fake key presses.
        write("\u{1B}[?2004h")
    }

    public func disableRawMode() {
        guard rawModeActive else { return }
        write("\u{1B}[?2004l")
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &originalTermios)
        rawModeActive = false
    }

    func restoreIfNeeded() {
        if rawModeActive {
            write("\u{1B}[?2004l")
            tcsetattr(STDIN_FILENO, TCSAFLUSH, &originalTermios)
        }
    }

    // MARK: - Output

    public func write(_ s: String) {
        guard let data = s.data(using: .utf8) else { return }
        data.withUnsafeBytes { ptr in
            _ = Darwin.write(STDOUT_FILENO, ptr.baseAddress!, ptr.count)
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
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0, ws.ws_col > 0 {
            return Int(ws.ws_col)
        }
        return 80
    }

    public var height: Int {
        var ws = winsize()
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0, ws.ws_row > 0 {
            return Int(ws.ws_row)
        }
        return 24
    }

    public var isInteractive: Bool { isatty(STDIN_FILENO) != 0 }

    // MARK: - Input

    /// Blocking read of the next key press.
    /// Safe to call from an async Task — blocks the OS thread, not the cooperative pool.
    public func readKey() -> Key {
        while true {
            if !pendingKeys.isEmpty {
                return pendingKeys.removeFirst()
            }
            if let key = takeParsedKey(flush: false) {
                return key
            }
            // The buffer holds an incomplete sequence. If nothing follows within
            // the grace period, force-resolve it (a lone ESC becomes .escape); an
            // unterminated bracketed paste still waits for its end marker.
            if !pendingBytes.isEmpty, !hasInput(timeoutMs: 25),
               let key = takeParsedKey(flush: true) {
                return key
            }
            guard readMore() else { return flushPendingBytes() }
        }
    }

    /// Parse buffered bytes, queue the resulting keys, and return the first.
    /// Returns nil when the buffer is empty or holds only an incomplete sequence.
    private func takeParsedKey(flush: Bool) -> Key? {
        guard !pendingBytes.isEmpty else { return nil }
        let (keys, consumed) = parseKeys(pendingBytes, flush: flush)
        pendingBytes.removeFirst(consumed)
        guard !keys.isEmpty else { return nil }
        pendingKeys.append(contentsOf: keys)
        return pendingKeys.removeFirst()
    }

    /// Blocking read of at least one byte, then drain whatever else the tty
    /// has buffered so a paste arrives in as few chunks as possible.
    /// Returns false on EOF or error.
    private func readMore() -> Bool {
        var tempBuf = [UInt8](repeating: 0, count: 1024)
        let n = Darwin.read(STDIN_FILENO, &tempBuf, tempBuf.count)
        guard n > 0 else { return false }
        pendingBytes.append(contentsOf: tempBuf[0..<n])

        while hasInput(timeoutMs: 0) {
            let m = Darwin.read(STDIN_FILENO, &tempBuf, tempBuf.count)
            guard m > 0 else { break }
            pendingBytes.append(contentsOf: tempBuf[0..<m])
        }
        return true
    }

    private func hasInput(timeoutMs: Int32) -> Bool {
        var pfd = pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0)
        return poll(&pfd, 1, timeoutMs) > 0
    }

    /// EOF: surface any leftover bytes as .unknown (empty on a clean EOF)
    /// rather than spinning.
    private func flushPendingBytes() -> Key {
        let bytes = pendingBytes
        pendingBytes.removeAll()
        return .unknown(bytes)
    }

    // MARK: - Key parsing

    private enum ScalarDecode {
        case scalar(UnicodeScalar, length: Int)
        /// A multi-byte sequence that runs past the end of the buffer.
        case truncated
        case invalid
    }

    /// Decode a single UTF-8 scalar starting at `i`.
    private func decodeScalar(at i: Int, in bytes: [UInt8]) -> ScalarDecode {
        let b = bytes[i]
        if b < 0x80 {
            return .scalar(UnicodeScalar(b), length: 1)
        }

        let length: Int
        if (b & 0xE0) == 0xC0 {
            length = 2
        } else if (b & 0xF0) == 0xE0 {
            length = 3
        } else if (b & 0xF8) == 0xF0 {
            length = 4
        } else {
            return .invalid
        }

        guard i + length <= bytes.count else { return .truncated }
        for j in (i + 1)..<(i + length) {
            guard (bytes[j] & 0xC0) == 0x80 else { return .invalid }
        }

        guard let string = String(bytes: bytes[i..<i+length], encoding: .utf8),
              let scalar = string.unicodeScalars.first else {
            return .invalid
        }
        return .scalar(scalar, length: length)
    }

    /// Parse raw terminal bytes into keys. This is what makes pasting work:
    /// a single `read()` can return many bytes, split into individual events.
    ///
    /// `consumed` is how many bytes were used. A trailing incomplete escape
    /// sequence, UTF-8 character, or unterminated bracketed paste is left
    /// unconsumed so the caller can retry once more bytes arrive.
    /// With `flush: true`, incomplete tails are resolved instead (a lone ESC
    /// becomes .escape) — except an unterminated paste, which always waits.
    func parseKeys(_ bytes: [UInt8], flush: Bool = false) -> (keys: [Key], consumed: Int) {
        var keys: [Key] = []
        var i = 0
        let count = bytes.count

        while i < count {
            let b = bytes[i]

            switch b {
            case 3:
                keys.append(.ctrlC)
                i += 1
            case 4:
                keys.append(.ctrlD)
                i += 1
            case 1:
                keys.append(.ctrlA)
                i += 1
            case 5:
                keys.append(.ctrlE)
                i += 1
            case 13, 10:
                // CR (Return) and LF (Ctrl+J, or non-bracketed pasted newlines)
                // both act as Enter. Bracketed pastes never reach this case.
                keys.append(.enter)
                i += 1
            case 127:
                keys.append(.backspace)
                i += 1
            case 9:
                keys.append(.tab)
                i += 1
            case 32:
                keys.append(.space)
                i += 1

            case 27:
                switch parseEscape(bytes, at: i, flush: flush) {
                case .key(let key, let length):
                    if let key { keys.append(key) }
                    i += length
                case .incomplete:
                    return (keys, i)
                }

            default:
                switch decodeScalar(at: i, in: bytes) {
                case .scalar(let scalar, let length):
                    keys.append(.char(Character(scalar)))
                    i += length
                case .truncated:
                    guard flush else { return (keys, i) }
                    keys.append(.unknown(Array(bytes[i..<count])))
                    i = count
                case .invalid:
                    keys.append(.unknown([b]))
                    i += 1
                }
            }
        }

        return (keys, count)
    }

    private enum EscapeParse {
        /// A parsed sequence of `length` bytes. A nil key means the bytes are
        /// consumed without emitting an event (e.g. a stray paste-end marker).
        case key(Key?, length: Int)
        case incomplete
    }

    /// Parse an escape sequence starting at `i` (bytes[i] is ESC).
    private func parseEscape(_ bytes: [UInt8], at i: Int, flush: Bool) -> EscapeParse {
        let count = bytes.count

        guard i + 1 < count else {
            return flush ? .key(.escape, length: 1) : .incomplete
        }

        switch bytes[i + 1] {
        case 91: // CSI: ESC [
            // Parameter bytes (0-9 ; : < = > ?), then intermediates, then a
            // final byte in 0x40...0x7E terminates the sequence.
            var j = i + 2
            while j < count, (0x30...0x3F).contains(bytes[j]) { j += 1 }
            let paramEnd = j
            while j < count, (0x20...0x2F).contains(bytes[j]) { j += 1 }
            guard j < count else {
                guard flush else { return .incomplete }
                return .key(.unknown(Array(bytes[i..<count])), length: count - i)
            }
            let final = bytes[j]
            guard (0x40...0x7E).contains(final) else {
                // Malformed: consume ESC [ and let the rest re-parse as text.
                return .key(.unknown(Array(bytes[i...i+1])), length: 2)
            }
            let length = j - i + 1
            let params = String(decoding: bytes[(i + 2)..<paramEnd], as: UTF8.self)

            if final == 126 { // '~'
                switch params {
                case "1", "7": return .key(.home, length: length)
                case "3":      return .key(.delete, length: length)
                case "4", "8": return .key(.end, length: length)
                case "5":      return .key(.pageUp, length: length)
                case "6":      return .key(.pageDown, length: length)
                case "200":    return parsePaste(bytes, markerStart: i, contentStart: j + 1)
                case "201":    return .key(nil, length: length) // stray end marker
                default:       return .key(.unknown(Array(bytes[i...j])), length: length)
                }
            }

            if params.isEmpty {
                switch final {
                case 65: return .key(.upArrow, length: length)
                case 66: return .key(.downArrow, length: length)
                case 67: return .key(.rightArrow, length: length)
                case 68: return .key(.leftArrow, length: length)
                case 72: return .key(.home, length: length)
                case 70: return .key(.end, length: length)
                default: break
                }
            }
            return .key(.unknown(Array(bytes[i...j])), length: length)

        case 79: // SS3: ESC O
            guard i + 2 < count else {
                guard flush else { return .incomplete }
                return .key(.unknown(Array(bytes[i..<count])), length: count - i)
            }
            switch bytes[i + 2] {
            case 72: return .key(.home, length: 3)
            case 70: return .key(.end, length: 3)
            default: return .key(.unknown(Array(bytes[i...i+2])), length: 3)
            }

        default:
            // ESC followed by an unrelated byte: a bare Escape key press;
            // the next byte parses on its own.
            return .key(.escape, length: 1)
        }
    }

    /// Scan for the bracketed-paste end marker (ESC [ 2 0 1 ~) and turn
    /// everything between the markers into a single .paste key. The content
    /// is never interpreted as key presses — pasted escape sequences stay text.
    private func parsePaste(_ bytes: [UInt8], markerStart: Int, contentStart: Int) -> EscapeParse {
        let endMarker = Array("\u{1B}[201~".utf8)
        var j = contentStart
        while j + endMarker.count <= bytes.count {
            if bytes[j] == 27, Array(bytes[j..<j+endMarker.count]) == endMarker {
                let content = String(decoding: bytes[contentStart..<j], as: UTF8.self)
                    .replacingOccurrences(of: "\r\n", with: "\n")
                    .replacingOccurrences(of: "\r", with: "\n")
                return .key(.paste(content), length: (j + endMarker.count) - markerStart)
            }
            j += 1
        }
        // End marker not received yet — wait for more bytes, even on flush.
        return .incomplete
    }
}

// MARK: - Paste sanitizing

extension String {
    /// Pasted text with control characters removed (tabs and newlines kept),
    /// so stray escape bytes can't corrupt the rendered prompt.
    var strippingControlCharacters: String {
        var view = String.UnicodeScalarView()
        for scalar in unicodeScalars
        where scalar == "\t" || scalar == "\n" || scalar.properties.generalCategory != .control {
            view.append(scalar)
        }
        return String(view)
    }
}
