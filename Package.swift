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
            name: "TestAudioCollector",
            targets: ["TestAudioCollector"]),
        .executable(
            name: "TestStreamingTTS",
            targets: ["TestStreamingTTS"]),
        .executable(
            name: "TestSentenceSplitter",
            targets: ["TestSentenceSplitter"]),
        .executable(
            name: "RecordScreen",
            targets: ["RecordScreen"]),
        .executable(
            name: "TranscribeVideo",
            targets: ["TranscribeVideo"]),
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
            path: "tests/test-download"),
        .executableTarget(
            name: "ListModels",
            dependencies: ["WhisperKit", "SharedModels"],
            path: "tools/list-models"),
        .executableTarget(
            name: "DeleteModels",
            dependencies: ["SharedModels"],
            path: "tools/delete-models"),
        .executableTarget(
            name: "DeleteModel",
            dependencies: ["SharedModels"],
            path: "tools/delete-model"),
        .executableTarget(
            name: "ValidateModels",
            dependencies: ["WhisperKit", "SharedModels"],
            path: "tools/validate-models"),
        .executableTarget(
            name: "TestTranscription",
            dependencies: ["WhisperKit", "SharedModels"],
            path: "tests/test-transcription"),
        .executableTarget(
            name: "TestLiveTranscription",
            dependencies: ["WhisperKit", "SharedModels"],
            path: "tests/test-live-transcription"),
        .executableTarget(
            name: "TestAudioCollector",
            dependencies: ["SharedModels"],
            path: "tests/test-audio-collector"),
        .executableTarget(
            name: "TestStreamingTTS",
            dependencies: ["SharedModels"],
            path: "tests/test-streaming-tts"),
        .executableTarget(
            name: "TestSentenceSplitter",
            dependencies: ["SharedModels"],
            path: "tests/test-sentence-splitter"),
        .executableTarget(
            name: "RecordScreen",
            dependencies: [],
            path: "tools/record-screen"),
        .executableTarget(
            name: "TranscribeVideo",
            dependencies: [],
            path: "tools/transcribe-video")
    ]
)
