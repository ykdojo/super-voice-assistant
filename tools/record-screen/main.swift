#!/usr/bin/env swift

import Foundation

print("🎥 Recording screen for 3 seconds...")
print("====================================\n")

// First, list all available devices
func listDevices() {
    let listProcess = Process()
    listProcess.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    listProcess.arguments = ["ffmpeg", "-f", "avfoundation", "-list_devices", "true", "-i", ""]

    let pipe = Pipe()
    listProcess.standardError = pipe

    do {
        try listProcess.run()
        listProcess.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        print("📱 Available Devices:")
        print("-------------------")

        var inVideoSection = false
        var inAudioSection = false

        for line in output.components(separatedBy: "\n") {
            if line.contains("AVFoundation video devices:") {
                inVideoSection = true
                inAudioSection = false
                print("\nVideo devices:")
                continue
            }
            if line.contains("AVFoundation audio devices:") {
                inVideoSection = false
                inAudioSection = true
                print("\nAudio devices:")
                continue
            }

            if (inVideoSection || inAudioSection) && line.contains("[") && line.contains("]") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if let range = trimmed.range(of: "\\[\\d+\\].*", options: .regularExpression) {
                    print("  " + String(trimmed[range]))
                }
            }
        }
        print("\n")
    } catch {
        print("⚠️  Could not list devices: \(error)\n")
    }
}

listDevices()

let timestamp = DateFormatter()
timestamp.dateFormat = "yyyy-MM-dd_HH-mm-ss"
let filename = "screen-recording-\(timestamp.string(from: Date())).mp4"
let desktopPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
let outputPath = desktopPath.appendingPathComponent(filename)

print("🎬 Recording Configuration:")
print("  Video: Device index 4 (screen capture)")
print("  Audio: System default input device")
print("  Output: \(outputPath.path)\n")

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
process.arguments = [
    "ffmpeg",
    "-f", "avfoundation",
    "-capture_cursor", "1",    // Show cursor in recording
    "-i", "4:default",         // Capture screen + system default audio input
    "-t", "3",                 // Duration: 3 seconds
    "-vcodec", "h264",         // Video codec
    "-acodec", "aac",          // Audio codec
    "-pix_fmt", "yuv420p",     // Pixel format for compatibility
    "-y",                      // Overwrite output file if exists
    outputPath.path
]

do {
    try process.run()
    process.waitUntilExit()

    if process.terminationStatus == 0 {
        print("\n✅ Recording saved to: \(filename)")
        exit(0)
    } else {
        print("\n❌ Recording failed with exit code \(process.terminationStatus)")
        print("\nNote: You may need to grant screen recording permissions in System Settings")
        exit(1)
    }
} catch {
    print("❌ Failed to start recording: \(error)")
    exit(1)
}
