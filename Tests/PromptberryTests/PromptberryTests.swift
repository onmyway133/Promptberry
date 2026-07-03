import Testing
import Foundation
@testable import Promptberry

// MARK: - Color tests
// Force colors on so tests are independent of whether stdout is a TTY.

@Suite(.serialized)
struct ColorTests {
    @Test func colorCyanWrapsWithANSI() {
        ColorSupport.enabled = true
        defer { ColorSupport.enabled = false }
        let result = "hello".cyan
        #expect(result.hasPrefix("\u{1B}[36m"))
        #expect(result.hasSuffix("\u{1B}[0m"))
        #expect(result.contains("hello"))
    }

    @Test func colorBoldWrapsWithANSI() {
        ColorSupport.enabled = true
        defer { ColorSupport.enabled = false }
        let result = "world".bold
        #expect(result.hasPrefix("\u{1B}[1m"))
        #expect(result.hasSuffix("\u{1B}[0m"))
    }

    @Test func colorRawStripsANSI() {
        ColorSupport.enabled = true
        defer { ColorSupport.enabled = false }
        let styled = "hello".red.bold
        #expect(styled.raw == "hello")
    }

    @Test func colorChaining() {
        ColorSupport.enabled = true
        defer { ColorSupport.enabled = false }
        let styled = "text".cyan.bold
        #expect(styled.raw == "text")
        #expect(styled.count > "text".count)
    }

    @Test func colorDisabledPassesThrough() {
        ColorSupport.enabled = false
        #expect("hello".cyan == "hello")
        #expect("world".bold == "world")
    }
}

// MARK: - isCancel tests

@Test func isCancelReturnsTrueForPromptCancelled() {
    #expect(isCancel(PromptCancelled(prompt: "Test prompt")))
}

@Test func isCancelReturnsFalseForOtherErrors() {
    struct OtherError: Error {}
    #expect(!isCancel(OtherError()))
}

@Test func isCancelReturnsFalseForURLError() {
    #expect(!isCancel(URLError(.badURL)))
}

// MARK: - PromptCancelled tests

@Test func promptCancelledCarriesPromptName() {
    let err = PromptCancelled(prompt: "What's your name?")
    #expect(err.prompt == "What's your name?")
}

@Test func promptCancelledDefaultsToEmptyPrompt() {
    let err = PromptCancelled()
    #expect(err.prompt == "")
}

// MARK: - Select windowing tests

@Test func selectVisibleRangeSmallList() {
    // Fewer items than maxVisible → return full range
    let prompt = SelectPrompt(
        message: "test",
        options: [
            SelectOption(value: "a", label: "A"),
            SelectOption(value: "b", label: "B"),
        ],
        initialValue: nil as String?,
        maxVisible: 5
    )
    let range = prompt.visibleRange(cursor: 0)
    #expect(range == 0..<2)
}

@Test func selectVisibleRangeCentersOnCursor() {
    // 10 options, maxVisible=3, cursor=5 → should produce 4..<7
    let options = (0..<10).map { SelectOption(value: "\($0)", label: "Item \($0)") }
    let prompt = SelectPrompt(
        message: "test",
        options: options,
        initialValue: nil as String?,
        maxVisible: 3
    )
    let range = prompt.visibleRange(cursor: 5)
    #expect(range == 4..<7)
}

@Test func selectVisibleRangeClampedAtStart() {
    let options = (0..<10).map { SelectOption(value: "\($0)", label: "Item \($0)") }
    let prompt = SelectPrompt(
        message: "test",
        options: options,
        initialValue: nil as String?,
        maxVisible: 4
    )
    let range = prompt.visibleRange(cursor: 0)
    #expect(range.lowerBound == 0)
    #expect(range.count == 4)
}

@Test func selectVisibleRangeClampedAtEnd() {
    let options = (0..<10).map { SelectOption(value: "\($0)", label: "Item \($0)") }
    let prompt = SelectPrompt(
        message: "test",
        options: options,
        initialValue: nil as String?,
        maxVisible: 4
    )
    let range = prompt.visibleRange(cursor: 9)
    #expect(range.upperBound == 10)
    #expect(range.count == 4)
}

// MARK: - Symbols tests

@Test func symbolsAreNonEmpty() {
    #expect(!Symbols.active.isEmpty)
    #expect(!Symbols.submitted.isEmpty)
    #expect(!Symbols.cancelled.isEmpty)
    #expect(!Symbols.bar.isEmpty)
    #expect(!Symbols.frames.isEmpty)
}

// MARK: - Terminal key parsing tests

@Test func parseKeysHandlesPastedASCII() {
    let (keys, consumed) = Terminal.shared.parseKeys(Array("Hello".utf8))
    #expect(keys == [.char("H"), .char("e"), .char("l"), .char("l"), .char("o")])
    #expect(consumed == 5)
}

@Test func parseKeysHandlesPastedUnicode() {
    let bytes = Array("Swift🚀".utf8)
    let (keys, consumed) = Terminal.shared.parseKeys(bytes)
    #expect(keys == [.char("S"), .char("w"), .char("i"), .char("f"), .char("t"), .char("🚀")])
    #expect(consumed == bytes.count)
}

@Test func parseKeysMapsControlsAndNewline() {
    let bytes: [UInt8] = [3, 13, 10, 9, 127, 32]
    let (keys, _) = Terminal.shared.parseKeys(bytes)
    #expect(keys == [.ctrlC, .enter, .enter, .tab, .backspace, .space])
}

@Test func parseKeysParsesEscapeSequences() {
    let bytes: [UInt8] = [27, 91, 65, 27, 91, 66]
    let (keys, consumed) = Terminal.shared.parseKeys(bytes)
    #expect(keys == [.upArrow, .downArrow])
    #expect(consumed == 6)
}

@Test func parseKeysHandlesMixedPasteWithEnter() {
    let bytes: [UInt8] = Array("Hi".utf8) + [13]
    let (keys, _) = Terminal.shared.parseKeys(bytes)
    #expect(keys == [.char("H"), .char("i"), .enter])
}

// MARK: - Split sequences across reads

@Test func parseKeysKeepsIncompleteEscapeSequence() {
    // "A" followed by the front half of an arrow-key sequence (ESC [).
    let (keys, consumed) = Terminal.shared.parseKeys([65, 27, 91])
    #expect(keys == [.char("A")])
    #expect(consumed == 1)  // ESC [ stays pending for the next read
}

@Test func parseKeysKeepsIncompleteUTF8() {
    let rocket = Array("🚀".utf8)
    let (keys, consumed) = Terminal.shared.parseKeys([72] + rocket.dropLast())
    #expect(keys == [.char("H")])
    #expect(consumed == 1)
}

@Test func parseKeysFlushResolvesLoneEscape() {
    let (keys, consumed) = Terminal.shared.parseKeys([27], flush: true)
    #expect(keys == [.escape])
    #expect(consumed == 1)
}

@Test func parseKeysWithoutFlushHoldsLoneEscape() {
    let (keys, consumed) = Terminal.shared.parseKeys([27])
    #expect(keys.isEmpty)
    #expect(consumed == 0)
}

@Test func parseKeysConsumesModifiedArrowAsUnknown() {
    // Shift+Up (ESC [ 1 ; 2 A) must be consumed whole, not leak ";2A" as chars.
    let bytes: [UInt8] = [27, 91, 49, 59, 50, 65] + Array("x".utf8)
    let (keys, consumed) = Terminal.shared.parseKeys(bytes)
    #expect(keys == [.unknown([27, 91, 49, 59, 50, 65]), .char("x")])
    #expect(consumed == bytes.count)
}

// MARK: - Bracketed paste

@Test func parseKeysDecodesBracketedPaste() {
    let bytes = Array("\u{1B}[200~line1\r\nline2\u{1B}[201~".utf8)
    let (keys, consumed) = Terminal.shared.parseKeys(bytes)
    #expect(keys == [.paste("line1\nline2")])
    #expect(consumed == bytes.count)
}

@Test func parseKeysKeepsEscapeSequencesInPasteLiteral() {
    // An arrow-key sequence inside a paste is text, not a key press.
    let bytes = Array("\u{1B}[200~a\u{1B}[Ab\u{1B}[201~".utf8)
    let (keys, _) = Terminal.shared.parseKeys(bytes)
    #expect(keys == [.paste("a\u{1B}[Ab")])
}

@Test func parseKeysWaitsForUnterminatedPaste() {
    let bytes = Array("\u{1B}[200~partial".utf8)
    let (keys, consumed) = Terminal.shared.parseKeys(bytes, flush: true)
    #expect(keys.isEmpty)
    #expect(consumed == 0)  // waits for the end marker even on flush
}

@Test func parseKeysHandlesKeysAroundPaste() {
    let bytes: [UInt8] = [13] + Array("\u{1B}[200~hi\u{1B}[201~".utf8) + [27, 91, 66]
    let (keys, consumed) = Terminal.shared.parseKeys(bytes)
    #expect(keys == [.enter, .paste("hi"), .downArrow])
    #expect(consumed == bytes.count)
}

// MARK: - Paste sanitizing

@Test func strippingControlCharactersKeepsTabsAndNewlines() {
    let dirty = "a\u{1B}[Cb\tc\nd\u{7}"
    #expect(dirty.strippingControlCharacters == "a[Cb\tc\nd")
}
