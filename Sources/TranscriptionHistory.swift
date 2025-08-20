import Foundation

struct TranscriptionEntry: Codable {
    let id: UUID
    let text: String
    let timestamp: Date
    
    init(text: String) {
        self.id = UUID()
        self.text = text
        self.timestamp = Date()
    }
}

class TranscriptionHistory {
    static let shared = TranscriptionHistory()
    private let maxEntries = 100
    private var entries: [TranscriptionEntry] = []
    
    private var historyFileURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let appSupportDir = documentsPath.appendingPathComponent("SuperVoiceAssistant", isDirectory: true)
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
        
        return appSupportDir.appendingPathComponent("transcription_history.json")
    }
    
    private init() {
        loadHistory()
    }
    
    private func loadHistory() {
        guard FileManager.default.fileExists(atPath: historyFileURL.path) else {
            print("No history file found")
            return
        }
        
        do {
            let data = try Data(contentsOf: historyFileURL)
            entries = try JSONDecoder().decode([TranscriptionEntry].self, from: data)
            print("Loaded \(entries.count) history entries")
        } catch {
            print("Failed to load history: \(error)")
        }
    }
    
    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: historyFileURL)
        } catch {
            print("Failed to save history: \(error)")
        }
    }
    
    func addEntry(_ text: String) {
        let entry = TranscriptionEntry(text: text)
        entries.insert(entry, at: 0) // Add at beginning for most recent first
        
        // Limit entries
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        
        saveHistory()
        
        // Update stats
        TranscriptionStats.shared.incrementTranscriptionCount()
        
        print("Added transcription to history: \(text)")
    }
    
    func getEntries() -> [TranscriptionEntry] {
        return entries
    }
    
    func clearHistory() {
        entries.removeAll()
        saveHistory()
    }
    
    func deleteEntry(at index: Int) {
        guard index >= 0 && index < entries.count else { return }
        entries.remove(at: index)
        saveHistory()
    }
}