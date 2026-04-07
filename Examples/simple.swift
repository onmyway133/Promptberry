import Promptberry
import Darwin

// A minimal project scaffolding wizard.
// Run with: swift run SimpleExample

@main
struct SimpleExample {
    static func main() async {
        do {
            Promptberry.intro("New Swift Project")

            let name = try Promptberry.text(
                "Project name?",
                placeholder: "MyApp",
                validate: { $0.isEmpty ? "Name cannot be empty." : nil }
            )

            let type_ = try Promptberry.select(
                "Project type:",
                options: ["Executable", "Library", "Plugin"],
                allowOther: true
            )

            let features = try Promptberry.multiselect(
                "Include extras:",
                options: ["Tests", "CI workflow", "README", "SwiftLint"],
                allowOther: true,
                initialValues: ["Tests", "README"]
            )

            let license = try Promptberry.autocomplete(
                "License:",
                options: ["MIT", "Apache 2.0", "GPL-3.0", "BSD-2-Clause", "BSD-3-Clause", "MPL-2.0", "Unlicense"],
                placeholder: "Type to filter..."
            )

            let description = try Promptberry.multiline(
                "Short description:",
                placeholder: "What does this project do?"
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

            // tasks() — sequential async steps with individual spinners
            try await tasks([
                PromptTask("Scaffolding project structure") {
                    try await Task.sleep(nanoseconds: 600_000_000)
                },
                PromptTask("Writing Package.swift") {
                    try await Task.sleep(nanoseconds: 400_000_000)
                },
                PromptTask("Installing dependencies") {
                    try await Task.sleep(nanoseconds: 800_000_000)
                },
            ])

            // progress bar
            let p = Promptberry.progress(total: 5, message: "Generating files...")
            for _ in 0..<5 {
                try await Task.sleep(nanoseconds: 200_000_000)
                await p.advance()
            }
            await p.complete(message: "Files generated!")

            Promptberry.note(
                "Type:     \(type_)\nExtras:   \(features.joined(separator: ", "))\nLicense:  \(license)\nAbout:    \(description)",
                title: name
            )

            log.success("Project created at ./\(name)/")
            log.info("Next: cd \(name) && swift build")

            Promptberry.outro("Happy coding!")

        } catch is PromptCancelled {
            Promptberry.cancel("Cancelled.")
            exit(0)
        } catch {
            log.error("Unexpected error: \(error)")
            exit(1)
        }
    }
}
