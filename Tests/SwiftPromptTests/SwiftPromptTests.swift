import Testing
import Foundation
@testable import SwiftPrompt

// MARK: - Color tests
// Force colors on so tests are independent of whether stdout is a TTY.

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
