import Foundation

// MARK: - Task definition

/// A single task for use with `Promptberry.tasks()`.
public struct PromptTask: Sendable {
    public let title: String
    public let task: @Sendable () async throws -> Void

    public init(_ title: String, task: @Sendable @escaping () async throws -> Void) {
        self.title = title
        self.task = task
    }
}

// MARK: - Tasks runner

/// Runs a list of tasks sequentially, showing a spinner for each one.
///
/// ```swift
/// try await Promptberry.tasks([
///     PromptTask("Install dependencies") { try await installDeps() },
///     PromptTask("Build project")        { try await build() },
///     PromptTask("Run tests")            { try await test() },
/// ])
/// ```
public func tasks(_ tasks: [PromptTask]) async throws {
    for item in tasks {
        let spinner = Spinner()
        await spinner.start(item.title)
        do {
            try await item.task()
            await spinner.stop(item.title)
        } catch {
            await spinner.error("\(item.title) — \(error)")
            throw error
        }
    }
}
