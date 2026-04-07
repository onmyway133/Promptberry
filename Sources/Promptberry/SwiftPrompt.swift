import Foundation

// MARK: - Promptable protocol

/// Conform your enum to `Promptable` to use it directly with `select` and `multiselect`.
///
/// ```swift
/// enum Language: String, CaseIterable, Promptable {
///     case swift, kotlin, python, rust
/// }
///
/// let lang  = try Promptberry.select("Language:", from: Language.self)
/// let langs = try Promptberry.multiselect("Languages:", from: Language.self)
/// ```
public protocol Promptable: CaseIterable, RawRepresentable, Sendable, Hashable
    where RawValue == String {}

// MARK: - Promptberry

/// Promptberry — Beautiful interactive CLI prompts for Swift.
///
/// Inspired by [clack](https://github.com/bombshell-dev/clack).
///
/// Usage:
/// ```swift
/// import Promptberry
///
/// Promptberry.intro("My App v1.0")
///
/// let name = try await Promptberry.text("What's your name?")
/// let go   = try await Promptberry.confirm("Continue?")
///
/// Promptberry.outro("Done!")
/// ```
public enum Promptberry {

    // MARK: - Frame

    /// Print a styled intro header.
    public static func intro(_ title: String) {
        let t = Terminal.shared
        t.writeLine("\(Symbols.topLeft.cyan)  \(title.bold)")
        t.writeLine(Symbols.bar.gray)
    }

    /// Print a styled outro footer.
    public static func outro(_ title: String) {
        let t = Terminal.shared
        t.writeLine(Symbols.bar.gray)
        t.writeLine("\(Symbols.bottomLeft.cyan)  \(title.bold)")
    }

    // MARK: - Info

    /// Display a bordered note box.
    public static func note(_ message: String, title: String = "") {
        let t = Terminal.shared
        let lines = message.components(separatedBy: "\n")
        let maxLen = lines.map { $0.raw.count }.max() ?? 0
        let titleLen = title.raw.count
        let width = max(maxLen, titleLen) + 2

        if !title.isEmpty {
            t.writeLine("\(Symbols.info.blue)  \(title.bold)")
        }
        t.writeLine("\(Symbols.bar.gray)  \(String(repeating: Symbols.dash, count: width).dim)")
        for line in lines {
            t.writeLine("\(Symbols.bar.gray)  \(line)")
        }
        t.writeLine("\(Symbols.bar.gray)  \(String(repeating: Symbols.dash, count: width).dim)")
    }

    /// Display a cancellation message.
    public static func cancel(_ message: String) {
        Terminal.shared.writeLine("\(Symbols.cancelled.red)  \(message.gray)")
    }

    // MARK: - Prompts

    /// Single-line text input.
    /// - Parameters:
    ///   - message: The prompt label.
    ///   - placeholder: Dimmed hint shown when input is empty.
    ///   - defaultValue: Value returned when user presses Enter on empty input.
    ///   - validate: Return an error string to reject the value, or `nil` to accept.
    public static func text(
        _ message: String,
        placeholder: String = "",
        defaultValue: String? = nil,
        validate: (@Sendable (String) -> String?)? = nil
    ) throws -> String {
        try TextPrompt(
            message: message,
            placeholder: placeholder,
            defaultValue: defaultValue,
            validate: validate
        ).run()
    }

    /// Password input — characters are masked.
    public static func password(
        _ message: String,
        mask: Character = "•"
    ) throws -> String {
        try PasswordPrompt(message: message, mask: mask).run()
    }

    /// Yes/No confirmation.
    public static func confirm(
        _ message: String,
        active: String = "Yes",
        inactive: String = "No",
        initialValue: Bool = true
    ) throws -> Bool {
        try ConfirmPrompt(
            message: message,
            activeLabel: active,
            inactiveLabel: inactive,
            initialValue: initialValue
        ).run()
    }

    /// Single-choice selection list.
    public static func select<Value: Sendable>(
        _ message: String,
        options: [SelectOption<Value>],
        initialValue: Value? = nil,
        maxItems: Int = 8
    ) throws -> Value {
        try SelectPrompt(
            message: message,
            options: options,
            initialValue: initialValue,
            maxVisible: maxItems
        ).run()
    }

    /// Convenience overload — pass plain strings instead of `SelectOption` values.
    ///
    /// ```swift
    /// let choice = try Promptberry.select("Pick one:", options: ["a", "b", "c"])
    /// ```
    public static func select(
        _ message: String,
        options: [String],
        initialValue: String? = nil,
        maxItems: Int = 8
    ) throws -> String {
        let opts = options.map { SelectOption(value: $0, label: $0) }
        return try SelectPrompt(
            message: message,
            options: opts,
            initialValue: initialValue,
            maxVisible: maxItems
        ).run()
    }

    /// Multi-choice selection list. Press Space to toggle, Enter to confirm.
    public static func multiselect<Value: Sendable & Hashable>(
        _ message: String,
        options: [SelectOption<Value>],
        initialValues: Set<Value> = [],
        required: Bool = true
    ) throws -> [Value] {
        try MultiselectPrompt(
            message: message,
            options: options,
            initialValues: initialValues,
            required: required,
            maxVisible: 8
        ).run()
    }

    /// Convenience overload — pass plain strings instead of `SelectOption` values.
    ///
    /// ```swift
    /// let features = try Promptberry.multiselect("Features:", options: ["tests", "ci", "docs"])
    /// ```
    public static func multiselect(
        _ message: String,
        options: [String],
        initialValues: Set<String> = [],
        required: Bool = true
    ) throws -> [String] {
        let opts = options.map { SelectOption(value: $0, label: $0) }
        return try MultiselectPrompt(
            message: message,
            options: opts,
            initialValues: initialValues,
            required: required,
            maxVisible: 8
        ).run()
    }

    // MARK: - Promptable enum overloads

    /// Select one case from a `Promptable` enum — no options array needed.
    ///
    /// ```swift
    /// enum Language: String, CaseIterable, Promptable {
    ///     case swift, kotlin, python
    /// }
    /// let lang = try Promptberry.select("Language:", from: Language.self)
    /// ```
    public static func select<T: Promptable>(
        _ message: String,
        from type_: T.Type,
        initialValue: T? = nil,
        maxItems: Int = 8
    ) throws -> T where T.AllCases: RandomAccessCollection {
        let opts = T.allCases.map { SelectOption(value: $0, label: $0.rawValue) }
        return try SelectPrompt(
            message: message,
            options: opts,
            initialValue: initialValue,
            maxVisible: maxItems
        ).run()
    }

    /// Select multiple cases from a `Promptable` enum — no options array needed.
    ///
    /// ```swift
    /// let features = try Promptberry.multiselect("Features:", from: Feature.self)
    /// ```
    public static func multiselect<T: Promptable>(
        _ message: String,
        from type_: T.Type,
        initialValues: Set<T> = [],
        required: Bool = true
    ) throws -> [T] where T.AllCases: RandomAccessCollection {
        let opts = T.allCases.map { SelectOption(value: $0, label: $0.rawValue) }
        return try MultiselectPrompt(
            message: message,
            options: opts,
            initialValues: initialValues,
            required: required,
            maxVisible: 8
        ).run()
    }

    /// Select one value from any array of `T`.
    ///
    /// The `label` closure converts each item to a display string.
    /// Defaults to `"\(item)"` so enums, strings, and any `CustomStringConvertible` work out of the box.
    ///
    /// ```swift
    /// // Promptable enum — rawValue used automatically
    /// let lang = try Promptberry.select("Language:", from: Language.allCases)
    ///
    /// // Any type with a custom label
    /// let server = try Promptberry.select("Server:", from: servers, label: { $0.hostname })
    ///
    /// // Filter before passing
    /// let lang = try Promptberry.select("Language:", from: Language.allCases.filter { $0 != .legacy })
    /// ```
    public static func select<T: Sendable & Hashable>(
        _ message: String,
        from values: some Collection<T>,
        label: (T) -> String = { "\($0)" },
        initialValue: T? = nil,
        maxItems: Int = 8
    ) throws -> T {
        let opts = values.map { SelectOption(value: $0, label: label($0)) }
        return try SelectPrompt(
            message: message,
            options: opts,
            initialValue: initialValue,
            maxVisible: maxItems
        ).run()
    }

    /// Select multiple values from any array of `T`.
    ///
    /// ```swift
    /// // Promptable enum
    /// let features = try Promptberry.multiselect("Features:", from: Feature.allCases)
    ///
    /// // Struct array with custom label
    /// let picked = try Promptberry.multiselect("Plugins:", from: plugins, label: { $0.name })
    /// ```
    public static func multiselect<T: Sendable & Hashable>(
        _ message: String,
        from values: some Collection<T>,
        label: (T) -> String = { "\($0)" },
        initialValues: Set<T> = [],
        required: Bool = true
    ) throws -> [T] {
        let opts = values.map { SelectOption(value: $0, label: label($0)) }
        return try MultiselectPrompt(
            message: message,
            options: opts,
            initialValues: initialValues,
            required: required,
            maxVisible: 8
        ).run()
    }

    /// Create a new spinner for async work.
    public static func spinner() -> Spinner {
        Spinner()
    }

    // MARK: - Group

    /// Run a sequence of prompts, with a shared cancellation handler.
    ///
    /// - Parameters:
    ///   - onCancel: Called with the cancelling prompt's message if the user aborts.
    ///   - body: A closure containing your prompt calls.
    /// - Returns: The value returned by `body`.
    @discardableResult
    public static func group<T: Sendable>(
        onCancel: @escaping @Sendable (String) -> Void = { _ in },
        _ body: () throws -> T
    ) throws -> T {
        do {
            return try body()
        } catch let err as PromptCancelled {
            onCancel(err.prompt)
            throw err
        }
    }
}
