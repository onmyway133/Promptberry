import SwiftPrompt
import Foundation

// swift-prompt demo — showcases all components

do {
    SwiftPrompt.intro("swift-prompt  demo")

    // --- Text ---
    let name = try SwiftPrompt.text(
        "What's your name?",
        placeholder: "e.g. Ada Lovelace",
        validate: { $0.count < 2 ? "Must be at least 2 characters." : nil }
    )

    // --- Password ---
    let _ = try SwiftPrompt.password("Choose a password:")

    // --- Confirm ---
    let newsletter = try SwiftPrompt.confirm(
        "Subscribe to updates?",
        active: "Yes please",
        inactive: "No thanks"
    )

    // --- Select ---
    let language = try SwiftPrompt.select(
        "Preferred language:",
        options: [
            SelectOption(value: "swift",  label: "Swift",  hint: "recommended"),
            SelectOption(value: "kotlin", label: "Kotlin"),
            SelectOption(value: "python", label: "Python", hint: "scripting"),
            SelectOption(value: "rust",   label: "Rust",   hint: "systems"),
            SelectOption(value: "go",     label: "Go",     hint: "backend"),
            SelectOption(value: "ts",     label: "TypeScript"),
        ],
        initialValue: "swift",
        maxItems: 4
    )

    // --- Multiselect ---
    let tools = try SwiftPrompt.multiselect(
        "Select build tools:",
        options: [
            SelectOption(value: "spm",   label: "Swift Package Manager"),
            SelectOption(value: "cmake", label: "CMake"),
            SelectOption(value: "bazel", label: "Bazel", hint: "large-scale"),
            SelectOption(value: "xcode", label: "Xcode", hint: "macOS"),
        ],
        initialValues: ["spm"],
        required: true
    )

    // --- Note ---
    SwiftPrompt.note(
        "Name: \(name)\nLanguage: \(language)\nTools: \(tools.joined(separator: ", "))\nNewsletter: \(newsletter ? "yes" : "no")",
        title: "Your selections"
    )

    // --- Spinner ---
    let s = SwiftPrompt.spinner()
    await s.start("Setting up your environment...")
    try await Task.sleep(nanoseconds: 1_500_000_000)
    await s.update("Almost there...")
    try await Task.sleep(nanoseconds: 700_000_000)
    await s.stop("Environment ready!")

    // --- Log messages ---
    log.info("Config saved to ~/.config/myapp")
    log.success("Build completed in 2.4s")
    log.warning("Deprecated API in one dependency")
    log.step("Running post-install scripts...")
    log.error("Optional linter not found (non-fatal)")

    // --- Group ---
    let profile = try SwiftPrompt.group(
        onCancel: { prompt in
            SwiftPrompt.cancel("Cancelled at: \(prompt)")
            exit(0)
        }
    ) {
        let email = try SwiftPrompt.text(
            "Email address?",
            placeholder: "you@example.com"
        )
        let age = try SwiftPrompt.text(
            "Your age?",
            validate: { Int($0) == nil ? "Please enter a number." : nil }
        )
        return (email: email, age: age)
    }

    log.success("Profile: \(profile.email), age \(profile.age)")

    SwiftPrompt.outro("All set! Happy coding, \(name).")

} catch is PromptCancelled {
    SwiftPrompt.cancel("Setup cancelled. See you next time!")
    exit(0)
} catch {
    log.error("Unexpected error: \(error)")
    exit(1)
}
