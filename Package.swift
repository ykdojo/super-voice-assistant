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
            targets: ["ListModels"]),
        .executable(
            name: "DeleteModels",
            targets: ["DeleteModels"]),
        .executable(
            name: "ValidateModels",
            targets: ["ValidateModels"]),
        .library(
            name: "SharedModels",
            targets: ["SharedModels"])
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
        .package(url: "https://github.com/argmaxinc/WhisperKit", from: "0.13.0")
    ],
    targets: [
        .target(
            name: "SharedModels",
            dependencies: ["WhisperKit"],
            path: "SharedSources"),
        .executableTarget(
            name: "SuperVoiceAssistant",
            dependencies: ["KeyboardShortcuts", "WhisperKit", "SharedModels"],
            path: "Sources",
            resources: [
                .copy("Assets.xcassets"),
                .copy("AppIcon.icns")
            ]),
        .executableTarget(
            name: "TestDownload",
            dependencies: ["WhisperKit", "SharedModels"],
            path: "TestSources"),
        .executableTarget(
            name: "ListModels",
            dependencies: ["WhisperKit", "SharedModels"],
            path: "ListModelsSources"),
        .executableTarget(
            name: "DeleteModels",
            dependencies: ["SharedModels"],
            path: "DeleteModelsSources"),
        .executableTarget(
            name: "ValidateModels",
            dependencies: ["WhisperKit", "SharedModels"],
            path: "ValidateModelsSources")
    ]
)
