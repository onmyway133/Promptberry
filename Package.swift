// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "swift-prompt",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "SwiftPrompt", targets: ["SwiftPrompt"])
    ],
    targets: [
        .target(
            name: "SwiftPrompt",
            path: "Sources/SwiftPrompt"
        ),
        .executableTarget(
            name: "Example",
            dependencies: ["SwiftPrompt"],
            path: "Sources/Example"
        ),
        .testTarget(
            name: "SwiftPromptTests",
            dependencies: ["SwiftPrompt"],
            path: "Tests/SwiftPromptTests"
        )
    ]
)
