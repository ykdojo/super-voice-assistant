import Foundation

/// Monitors memory usage and logs warnings when thresholds are exceeded
class MemoryMonitor {
    static let shared = MemoryMonitor()

    private var timer: Timer?
    private var lastLoggedThreshold: UInt64 = 0
    private let thresholdsMB: [UInt64] = [500, 1000, 2000, 5000, 10000, 20000, 50000]

    private init() {}

    /// Start monitoring memory usage
    func start(intervalSeconds: Double = 1.0) {
        stop()

        print("🔍 Memory monitor started (checking every \(intervalSeconds)s)")
        logCurrentMemory()

        timer = Timer.scheduledTimer(withTimeInterval: intervalSeconds, repeats: true) { [weak self] _ in
            self?.checkMemory()
        }
    }

    /// Stop monitoring
    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Get current memory usage in bytes
    func currentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return 0
        }

        return info.resident_size
    }

    /// Log current memory usage
    func logCurrentMemory() {
        let bytes = currentMemoryUsage()
        let mb = bytes / (1024 * 1024)
        print("📊 Current memory: \(mb) MB")
    }

    private func checkMemory() {
        let bytes = currentMemoryUsage()
        let mb = bytes / (1024 * 1024)

        // Find the highest threshold we've crossed
        var crossedThreshold: UInt64 = 0
        for threshold in thresholdsMB {
            if mb >= threshold {
                crossedThreshold = threshold
            }
        }

        // Log if we crossed a new threshold
        if crossedThreshold > lastLoggedThreshold {
            print("⚠️ MEMORY WARNING: \(mb) MB (crossed \(crossedThreshold) MB threshold)")
            logMemoryContext()
            lastLoggedThreshold = crossedThreshold
        }

        // Reset threshold tracking if memory drops significantly
        if mb < lastLoggedThreshold / 2 {
            lastLoggedThreshold = 0
        }
    }

    /// Log context about what might be using memory
    private func logMemoryContext() {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("   Timestamp: \(timestamp)")
        print("   Thread: \(Thread.current)")

        // Log call stack for debugging
        let symbols = Thread.callStackSymbols.prefix(10)
        print("   Stack trace:")
        for symbol in symbols {
            print("     \(symbol)")
        }
    }
}
