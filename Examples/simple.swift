import Promptberry
import Darwin

// A minimal project scaffolding wizard.
// Run with: swift run SimpleExample

do {
    Promptberry.intro("New Swift Project")

    let name = try Promptberry.text(
        "Project name?",
        placeholder: "MyApp",
        validate: { $0.isEmpty ? "Name cannot be empty." : nil }
    )

    let type_ = try Promptberry.select(
        "Project type:",
        options: ["Executable", "Library", "Plugin"]
    )

    let features = try Promptberry.multiselect(
        "Include extras:",
        options: ["Tests", "CI workflow", "README", "SwiftLint"],
        initialValues: ["Tests", "README"]
    )

    let confirmed = try Promptberry.confirm(
        "Create \"\(name)\"?",
        active: "Yes, create it",
        inactive: "No, cancel"
    )

    guard confirmed else {
        Promptberry.cancel("Nothing created.")
        exit(0)
    }

    let spinner = Promptberry.spinner()
    await spinner.start("Scaffolding project...")
    try await Task.sleep(nanoseconds: 1_200_000_000)
    await spinner.stop("Done!")

    Promptberry.note(
        features.joined(separator: "\n"),
        title: "\(name) (\(type_))"
    )

    log.success("Project created at ./\(name)/")
    log.info("Next: cd \(name) && swift build")

    Promptberry.outro("Happy coding!")

} catch is PromptCancelled {
    Promptberry.cancel("Cancelled.")
    exit(0)
}
