// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Choco",
    defaultLocalization: "en",
    platforms: [.macOS("15.4")],
    products: [
        .library(name: "BrowserLocalization", targets: ["BrowserLocalization"]),
        .library(name: "BrowserCore", targets: ["BrowserCore"]),
        .library(name: "BrowserRuntime", targets: ["BrowserRuntime"]),
        .executable(name: "Choco", targets: ["BrowserApp"])
    ],
    targets: [
        .target(name: "BrowserLocalization", resources: [.process("Resources")]),
        .target(name: "BrowserCore", dependencies: ["BrowserLocalization"]),
        .target(name: "BrowserRuntime", dependencies: ["BrowserLocalization"]),
        .executableTarget(name: "BrowserApp", dependencies: ["BrowserCore", "BrowserRuntime", "BrowserLocalization"]),
        .testTarget(name: "BrowserLocalizationTests", dependencies: ["BrowserLocalization"]),
        .testTarget(name: "BrowserCoreTests", dependencies: ["BrowserCore"]),
        .testTarget(name: "BrowserRuntimeTests", dependencies: ["BrowserRuntime"]),
        .testTarget(name: "BrowserAcceptanceTests", dependencies: ["BrowserCore", "BrowserRuntime"]),
        .testTarget(name: "BrowserAppTests", dependencies: ["BrowserApp"])
    ]
)
