import Foundation

class TranscriptionStats {
    static let shared = TranscriptionStats()
    private var totalTranscriptions: Int = 0
    
    private var statsFileURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let appSupportDir = documentsPath.appendingPathComponent("SuperVoiceAssistant", isDirectory: true)
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
        
        return appSupportDir.appendingPathComponent("transcription_stats.json")
    }
    
    private init() {
        loadStats()
    }
    
    private func loadStats() {
        guard FileManager.default.fileExists(atPath: statsFileURL.path) else {
            print("No stats file found, starting fresh")
            return
        }
        
        do {
            let data = try Data(contentsOf: statsFileURL)
            if let stats = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let count = stats["totalTranscriptions"] as? Int {
                totalTranscriptions = count
                print("Loaded stats: \(totalTranscriptions) total transcriptions")
            }
        } catch {
            print("Failed to load stats: \(error)")
        }
    }
    
    private func saveStats() {
        do {
            let stats: [String: Any] = ["totalTranscriptions": totalTranscriptions]
            let data = try JSONSerialization.data(withJSONObject: stats, options: .prettyPrinted)
            try data.write(to: statsFileURL)
        } catch {
            print("Failed to save stats: \(error)")
        }
    }
    
    func incrementTranscriptionCount() {
        totalTranscriptions += 1
        saveStats()
        print("Total transcriptions: \(totalTranscriptions)")
    }
    
    func getTotalTranscriptions() -> Int {
        return totalTranscriptions
    }
}