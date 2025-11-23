import Foundation

class ScreenRecorder {
    private var recordingProcess: Process?
    private var outputURL: URL?
    private var isRecording = false

    /// Start screen recording
    /// - Parameter completion: Called when recording starts or fails
    func startRecording(completion: @escaping (Result<URL, Error>) -> Void) {
        guard !isRecording else {
            completion(.failure(ScreenRecorderError.alreadyRecording))
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
        process.arguments = [
            "ffmpeg",
            "-f", "avfoundation",
            "-capture_cursor", "1",
            "-i", "4:default",  // Screen + system audio
            "-vcodec", "h264",
            "-acodec", "aac",
            "-pix_fmt", "yuv420p",
            "-y",
            outputPath.path
        ]

        // Redirect stdin to prevent ffmpeg from waiting for input
        let devNull = FileHandle(forReadingAtPath: "/dev/null")
        process.standardInput = devNull

        // Capture stderr for errors
        let pipe = Pipe()
        process.standardError = pipe

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

        // Send 'q' command to ffmpeg to gracefully stop
        if let stdin = process.standardInput as? Pipe {
            let qCommand = "q\n".data(using: .utf8)!
            try? stdin.fileHandleForWriting.write(contentsOf: qCommand)
        } else {
            // Fallback: send SIGINT for graceful termination
            process.interrupt()
        }

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

                if process.terminationStatus == 0 {
                    print("✅ Screen recording saved: \(outputURL.lastPathComponent)")
                    completion(.success(outputURL))
                } else {
                    print("❌ Screen recording failed with exit code \(process.terminationStatus)")
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
    case recordingFailed(exitCode: Int32)

    var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            return "Screen recording is already in progress"
        case .notRecording:
            return "No screen recording in progress"
        case .recordingFailed(let exitCode):
            return "Screen recording failed with exit code \(exitCode)"
        }
    }
}
