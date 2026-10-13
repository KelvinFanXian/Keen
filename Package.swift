// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Keen",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "Keen", targets: ["Keen"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.8.0")
    ],
    targets: [
        .executableTarget(
            name: "Keen",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown")
            ],
            path: "Sources/Keen",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "KeenTests",
            dependencies: ["Keen"],
            path: "Tests/KeenTests"
        )
    ]
)
