// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SuperVoiceAssistant",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "SuperVoiceAssistant",
            targets: ["SuperVoiceAssistant"]),
        .executable(
            name: "TestDownload",
            targets: ["TestDownload"]),
        .executable(
            name: "ListModels",
            targets: ["ListModels"])
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
        .package(url: "https://github.com/argmaxinc/WhisperKit", from: "0.13.0")
    ],
    targets: [
        .executableTarget(
            name: "SuperVoiceAssistant",
            dependencies: ["KeyboardShortcuts", "WhisperKit"],
            path: "Sources"),
        .executableTarget(
            name: "TestDownload",
            dependencies: ["WhisperKit"],
            path: "TestSources"),
        .executableTarget(
            name: "ListModels",
            dependencies: ["WhisperKit"],
            path: "ListModelsSources")
    ]
)
