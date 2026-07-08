import Foundation

/// Monitors memory usage and logs warnings when thresholds are exceeded.
/// Uses a background GCD timer so it fires even when the main thread is blocked.
public class MemoryMonitor {
    public static let shared = MemoryMonitor()

    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "memory-monitor", qos: .utility)
    private var lastLoggedThreshold: UInt64 = 0
    private let thresholdsMB: [UInt64] = [500, 1000, 2000, 5000, 10000]
    private var logFileHandle: FileHandle?
    private let logFilePath: String

    private init() {
        let logsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/SuperVoiceAssistant")
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        logFilePath = logsDir.appendingPathComponent("memory.log").path
    }

    /// Start monitoring memory usage
    public func start(intervalSeconds: Double = 2.0) {
        stop()

        // Open log file for appending
        if !FileManager.default.fileExists(atPath: logFilePath) {
            FileManager.default.createFile(atPath: logFilePath, contents: nil)
        }
        logFileHandle = FileHandle(forWritingAtPath: logFilePath)
        logFileHandle?.seekToEndOfFile()

        let message = "🔍 Memory monitor started (checking every \(intervalSeconds)s) - Log: \(logFilePath)"
        print(message)
        writeToLog(message)

        let mb = currentMemoryMB()
        let startMsg = "📊 Current memory: \(mb) MB"
        print(startMsg)
        writeToLog(startMsg)

        // Use DispatchSourceTimer on a background queue so it fires
        // even when the main thread is blocked by a tight allocation loop.
        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now() + intervalSeconds, repeating: intervalSeconds)
        source.setEventHandler { [weak self] in
            self?.checkMemory()
        }
        source.resume()
        timer = source
    }

    /// Stop monitoring
    public func stop() {
        timer?.cancel()
        timer = nil
        logFileHandle?.closeFile()
        logFileHandle = nil
    }

    // MARK: - Checkpoints

    /// Log memory at an operation boundary so we can see what caused a spike.
    public func checkpoint(_ label: String) {
        let mb = currentMemoryMB()
        let message = "📍 [\(label)] memory: \(mb) MB"
        print(message)
        writeToLog(message)
    }

    // MARK: - Internals

    private func writeToLog(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logLine = "[\(timestamp)] \(message)\n"
        if let data = logLine.data(using: .utf8) {
            logFileHandle?.write(data)
            logFileHandle?.synchronizeFile()
        }
    }

    public func currentMemoryMB() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }
        return info.resident_size / (1024 * 1024)
    }

    private func checkMemory() {
        let mb = currentMemoryMB()

        // Find the highest threshold we've crossed
        var crossedThreshold: UInt64 = 0
        for threshold in thresholdsMB {
            if mb >= threshold {
                crossedThreshold = threshold
            }
        }

        // Log if we crossed a new threshold
        if crossedThreshold > lastLoggedThreshold {
            let message = "⚠️ MEMORY WARNING: \(mb) MB (crossed \(crossedThreshold) MB threshold)"
            print(message)
            writeToLog(message)
            lastLoggedThreshold = crossedThreshold
        }

        // Reset threshold tracking if memory drops significantly
        if mb < lastLoggedThreshold / 2 {
            lastLoggedThreshold = 0
        }
    }
}
