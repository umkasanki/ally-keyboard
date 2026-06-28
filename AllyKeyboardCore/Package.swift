// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AllyKeyboardCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "AllyKeyboardCore", targets: ["AllyKeyboardCore"]),
    ],
    targets: [
        .target(
            name: "AllyKeyboardCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "AllyKeyboardCoreTests",
            dependencies: ["AllyKeyboardCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
