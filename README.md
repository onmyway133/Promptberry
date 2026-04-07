# swift-prompt

Beautiful, interactive CLI prompts for Swift. Inspired by [clack](https://github.com/bombshell-dev/clack).

```
┌  My App v1.0
│
◆  What's your name?
│  ▌ Ada_
│
◆  Select language:
│  › ● Swift  (recommended)
│    ○ Kotlin
│    ○ Python
│
⠋  Installing...
◇  Done!
│
└  Happy coding, Ada.
```

## Requirements

- Swift 6.0+
- macOS 13+

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourname/swift-prompt", from: "1.0.0")
],
targets: [
    .executableTarget(
        name: "MyApp",
        dependencies: [
            .product(name: "SwiftPrompt", package: "swift-prompt")
        ]
    )
]
```

## Usage

```swift
import SwiftPrompt

SwiftPrompt.intro("My App v1.0")

let name = try SwiftPrompt.text("What's your name?", placeholder: "e.g. Ada")
let pass = try SwiftPrompt.password("Choose a password:")
let go   = try SwiftPrompt.confirm("Continue?")

SwiftPrompt.outro("All done, \(name)!")
```

Wrap everything in a `do/catch` to handle cancellation (Ctrl+C):

```swift
do {
    let name = try SwiftPrompt.text("Name?")
} catch is PromptCancelled {
    SwiftPrompt.cancel("Aborted.")
    exit(0)
}
```

## Prompts

### `text`

Single-line text input.

```swift
let name = try SwiftPrompt.text(
    "What's your name?",
    placeholder: "e.g. Ada Lovelace",   // shown when empty
    defaultValue: "Anonymous",           // returned on empty Enter
    validate: { value in
        value.count < 2 ? "Too short." : nil
    }
)
```

### `password`

Like `text`, but input is masked.

```swift
let secret = try SwiftPrompt.password("Password:", mask: "•")
```

### `confirm`

Yes/No toggle. Use arrow keys, `y`/`n`, or Space to switch.

```swift
let ok = try SwiftPrompt.confirm(
    "Continue?",
    active: "Yes",
    inactive: "No",
    initialValue: true
)
```

### `select`

Pick one item from a list. Navigate with `↑`/`↓` or `j`/`k`.

```swift
let lang = try SwiftPrompt.select(
    "Preferred language:",
    options: [
        SelectOption(value: "swift",  label: "Swift",  hint: "recommended"),
        SelectOption(value: "kotlin", label: "Kotlin"),
        SelectOption(value: "python", label: "Python"),
    ],
    initialValue: "swift",
    maxItems: 5          // how many options to show at once
)
```

### `multiselect`

Pick multiple items. Space to toggle, `a` to toggle all, Enter to confirm.

```swift
let tools = try SwiftPrompt.multiselect(
    "Build tools:",
    options: [
        SelectOption(value: "spm",   label: "Swift Package Manager"),
        SelectOption(value: "cmake", label: "CMake"),
        SelectOption(value: "bazel", label: "Bazel", hint: "large-scale"),
    ],
    initialValues: ["spm"],
    required: true       // at least one must be selected
)
// returns [String]
```

### `spinner`

Show an animated spinner while doing async work.

```swift
let s = SwiftPrompt.spinner()
await s.start("Installing packages...")

try await installPackages()    // your async work runs concurrently

await s.stop("Packages installed!")    // or s.error("Failed.")
```

You can update the message while it's running:

```swift
await s.update("Almost there...")
```

## Info & Logging

```swift
// Bordered info box
SwiftPrompt.note("Line 1\nLine 2", title: "Important")

// Cancellation message
SwiftPrompt.cancel("Setup aborted.")

// Semantic log lines (non-interactive)
log.info("Reading config...")
log.success("Build passed in 1.2s")
log.warning("Deprecated API used")
log.step("Running post-install hooks")
log.error("Connection refused (non-fatal)")
```

## Group

Sequence multiple prompts with a shared cancellation handler:

```swift
let profile = try SwiftPrompt.group(
    onCancel: { _ in
        SwiftPrompt.cancel("Cancelled.")
        exit(0)
    }
) {
    let email = try SwiftPrompt.text("Email?")
    let age   = try SwiftPrompt.text("Age?",
        validate: { Int($0) == nil ? "Enter a number." : nil })
    return (email: email, age: age)
}
```

## Colors

All strings support Rainbow-style chaining:

```swift
"success".green.bold
"warning".yellow
"error".red
"hint".dim
"label".cyan.underline
"bg".onBlue
```

Disable colors globally (e.g. for piped output):

```swift
ColorSupport.enabled = false
```

Colors are also auto-disabled when:
- `NO_COLOR` environment variable is set
- stdout is not a TTY (piped to a file)
- `TERM=dumb`

Force colors on even in non-TTY contexts:

```swift
ColorSupport.enabled = true
// or set FORCE_COLOR=1 in the environment
```

## Example

Run the bundled demo:

```bash
swift run Example
```

## License

MIT
