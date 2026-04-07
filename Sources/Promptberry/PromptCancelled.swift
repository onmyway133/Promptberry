/// Thrown when the user cancels a prompt via Ctrl+C or Escape.
public struct PromptCancelled: Error, Sendable {
    public let prompt: String
    public init(prompt: String = "") {
        self.prompt = prompt
    }
}

/// Returns `true` if the given error is a `PromptCancelled`.
/// Mirrors clack's `isCancel()` API.
public func isCancel(_ error: Error) -> Bool {
    error is PromptCancelled
}
