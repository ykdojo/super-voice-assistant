import Foundation

class ScreenRecorder {
    private var recordingProcess: Process?
    private var outputURL: URL?
    private var isRecording = false

    /// Detect the main screen capture device index by parsing ffmpeg's device list
    private func detectMainScreenDeviceIndex() -> Int? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["ffmpeg", "-f", "avfoundation", "-list_devices", "true", "-i", ""]

        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        process.standardOutput = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard let output = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) else {
            return nil
        }

        var inVideoSection = false
        for line in output.components(separatedBy: "\n") {
            if line.contains("AVFoundation video devices:") {
                inVideoSection = true
                continue
            }
            if line.contains("AVFoundation audio devices:") {
                inVideoSection = false
                continue
            }

            if inVideoSection {
                // Pattern: [index] Device Name
                let pattern = #"\[(\d+)\]\s+(.+)$"#
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                   let indexRange = Range(match.range(at: 1), in: line),
                   let nameRange = Range(match.range(at: 2), in: line) {
                    let name = String(line[nameRange])
                    // Main display is always "Capture screen 0"
                    if name.contains("Capture screen 0") {
                        return Int(line[indexRange])
                    }
                }
            }
        }
        return nil
    }

    /// Start screen recording
    /// - Parameter completion: Called when recording starts or fails
    func startRecording(completion: @escaping (Result<URL, Error>) -> Void) {
        guard !isRecording else {
            completion(.failure(ScreenRecorderError.alreadyRecording))
            return
        }

        // Detect screen device
        guard let videoDeviceIndex = detectMainScreenDeviceIndex() else {
            print("❌ Could not detect screen capture device")
            completion(.failure(ScreenRecorderError.noScreenDevice))
            return
        }

        // Generate output filename
        let timestamp = DateFormatter()
        timestamp.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "screen-recording-\(timestamp.string(from: Date())).mp4"
        let desktopPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        let outputPath = desktopPath.appendingPathComponent(filename)

        self.outputURL = outputPath

        // Create ffmpeg process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        let videoDevice = String(videoDeviceIndex)
        let audioDevice = "default"

        process.arguments = [
            "ffmpeg",
            "-f", "avfoundation",
            "-capture_cursor", "1",
            "-i", "\(videoDevice):\(audioDevice)",
            "-vcodec", "h264",
            "-acodec", "aac",
            "-pix_fmt", "yuv420p",
            "-y",
            outputPath.path
        ]

        print("🎥 Detected video device: \(videoDevice) (Capture screen 0)")
        print("🎤 Using audio device: \(audioDevice)")

        // Redirect stdin to /dev/null since we use SIGINT to stop
        process.standardInput = FileHandle.nullDevice

        // Capture stderr for errors (suppress ffmpeg output)
        process.standardError = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice

        self.recordingProcess = process

        do {
            try process.run()
            self.isRecording = true
            completion(.success(outputPath))
            print("🎥 Screen recording started: \(filename)")
        } catch {
            completion(.failure(error))
            print("❌ Failed to start screen recording: \(error)")
        }
    }

    /// Stop screen recording
    /// - Parameter completion: Called when recording stops with the output file URL
    func stopRecording(completion: @escaping (Result<URL, Error>) -> Void) {
        guard isRecording, let process = recordingProcess, let outputURL = outputURL else {
            completion(.failure(ScreenRecorderError.notRecording))
            return
        }

        // Use SIGINT to gracefully stop ffmpeg (equivalent to Ctrl+C)
        // This is more reliable than sending 'q' via stdin pipe
        print("📝 Sending SIGINT to ffmpeg")
        process.interrupt()

        // Wait for process to finish (with timeout)
        DispatchQueue.global(qos: .userInitiated).async {
            let maxWaitTime = 10.0
            let startTime = Date()

            while process.isRunning {
                if Date().timeIntervalSince(startTime) > maxWaitTime {
                    print("⚠️  Recording stop timed out - terminating forcefully")
                    process.terminate()
                    break
                }
                Thread.sleep(forTimeInterval: 0.1)
            }

            DispatchQueue.main.async {
                self.isRecording = false
                self.recordingProcess = nil

                // Exit code 255 (or 251 on some systems) is normal when ffmpeg is interrupted with SIGINT
                // Check if the output file exists and has content as the real success indicator
                let fileExists = FileManager.default.fileExists(atPath: outputURL.path)
                let fileSize = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int) ?? 0

                if fileExists && fileSize > 0 {
                    print("✅ Screen recording saved: \(outputURL.lastPathComponent) (\(fileSize) bytes)")
                    completion(.success(outputURL))
                } else {
                    print("❌ Screen recording failed - file not created or empty (exit code: \(process.terminationStatus))")
                    completion(.failure(ScreenRecorderError.recordingFailed(exitCode: process.terminationStatus)))
                }
            }
        }
    }

    var recording: Bool {
        return isRecording
    }
}

enum ScreenRecorderError: Error, LocalizedError {
    case alreadyRecording
    case notRecording
    case noScreenDevice
    case recordingFailed(exitCode: Int32)

    var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            return "Screen recording is already in progress"
        case .notRecording:
            return "No screen recording in progress"
        case .noScreenDevice:
            return "Could not detect screen capture device"
        case .recordingFailed(let exitCode):
            return "Screen recording failed with exit code \(exitCode)"
        }
    }
}
