// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Choco",
    platforms: [.macOS("15.4")],
    products: [
        .library(name: "BrowserCore", targets: ["BrowserCore"]),
        .library(name: "BrowserRuntime", targets: ["BrowserRuntime"]),
        .executable(name: "Choco", targets: ["BrowserApp"])
    ],
    targets: [
        .target(name: "BrowserCore"),
        .target(name: "BrowserRuntime"),
        .executableTarget(name: "BrowserApp", dependencies: ["BrowserCore", "BrowserRuntime"], resources: [.process("Resources")]),
        .testTarget(name: "BrowserCoreTests", dependencies: ["BrowserCore"]),
        .testTarget(name: "BrowserRuntimeTests", dependencies: ["BrowserRuntime"]),
        .testTarget(name: "BrowserAcceptanceTests", dependencies: ["BrowserCore", "BrowserRuntime"]),
        .testTarget(name: "BrowserAppTests", dependencies: ["BrowserApp"])
    ]
)
