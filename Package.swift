// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Promptberry",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "Promptberry", targets: ["Promptberry"])
    ],
    targets: [
        .target(
            name: "Promptberry",
            path: "Sources/Promptberry"
        ),
        .executableTarget(
            name: "Example",
            dependencies: ["Promptberry"],
            path: "Sources/Example"
        ),
        .executableTarget(
            name: "SimpleExample",
            dependencies: ["Promptberry"],
            path: "Examples"
        ),
        .testTarget(
            name: "PromptberryTests",
            dependencies: ["Promptberry"],
            path: "Tests/PromptberryTests"
        )
    ]
)
