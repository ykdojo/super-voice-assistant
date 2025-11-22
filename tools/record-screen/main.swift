#!/usr/bin/env swift

import Foundation

print("🎥 Recording screen for 3 seconds...")
print("====================================\n")

// Note: To list available devices, run: ffmpeg -f avfoundation -list_devices true -i ""

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

// Redirect stdin to /dev/null to prevent ffmpeg from waiting for input
let devNull = FileHandle(forReadingAtPath: "/dev/null")
process.standardInput = devNull

do {
    try process.run()

    // Wait with timeout
    let maxWaitTime = 10.0 // 10 seconds max (3s recording + overhead)
    let startTime = Date()

    while process.isRunning {
        if Date().timeIntervalSince(startTime) > maxWaitTime {
            print("\n⚠️  Recording timed out - killing process")
            process.terminate()
            Thread.sleep(forTimeInterval: 0.5)
            if process.isRunning {
                process.interrupt()
            }
            print("\n❌ Recording failed: timeout waiting for ffmpeg")
            print("\nNote: Check System Settings → Privacy & Security → Screen Recording")
            print("      Make sure 'Terminal' or your terminal app has permission")
            exit(1)
        }
        Thread.sleep(forTimeInterval: 0.1)
    }

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
