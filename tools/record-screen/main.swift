#!/usr/bin/env swift

import Foundation

print("🎥 Recording screen for 3 seconds...")
print("====================================\n")

let timestamp = DateFormatter()
timestamp.dateFormat = "yyyy-MM-dd_HH-mm-ss"
let filename = "screen-recording-\(timestamp.string(from: Date())).mp4"
let desktopPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
let outputPath = desktopPath.appendingPathComponent(filename)

print("Output: \(outputPath.path)\n")

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
process.arguments = [
    "ffmpeg",
    "-f", "avfoundation",
    "-i", "4:none",           // Capture screen 0, no audio
    "-t", "3",                // Duration: 3 seconds
    "-vcodec", "h264",        // Video codec
    "-pix_fmt", "yuv420p",    // Pixel format for compatibility
    "-y",                     // Overwrite output file if exists
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
