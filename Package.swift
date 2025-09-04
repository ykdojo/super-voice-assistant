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
            name: "DeleteModel",
            targets: ["DeleteModel"]),
        .executable(
            name: "ValidateModels",
            targets: ["ValidateModels"]),
        .executable(
            name: "TestTranscription",
            targets: ["TestTranscription"]),
        .executable(
            name: "TestLiveTranscription",
            targets: ["TestLiveTranscription"]),
        .executable(
            name: "TestGeminiLive",
            targets: ["TestGeminiLive"]),
        .executable(
            name: "TestStreamingTTS",
            targets: ["TestStreamingTTS"]),
        .library(
            name: "SharedModels",
            targets: ["SharedModels"])
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", exact: "1.8.0"),
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
            name: "DeleteModel",
            dependencies: ["SharedModels"],
            path: "DeleteModelSources"),
        .executableTarget(
            name: "ValidateModels",
            dependencies: ["WhisperKit", "SharedModels"],
            path: "ValidateModelsSources"),
        .executableTarget(
            name: "TestTranscription",
            dependencies: ["WhisperKit", "SharedModels"],
            path: "TestTranscriptionSources"),
        .executableTarget(
            name: "TestLiveTranscription",
            dependencies: ["WhisperKit", "SharedModels"],
            path: "TestLiveTranscriptionSources"),
        .executableTarget(
            name: "TestGeminiLive",
            dependencies: ["SharedModels"],
            path: "TestGeminiLiveSources"),
        .executableTarget(
            name: "TestStreamingTTS",
            dependencies: ["SharedModels"],
            path: "TestStreamingTTSSources")
    ]
)
