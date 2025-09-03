import Foundation
import SharedModels

@main
struct GeminiLiveTest {
    static func loadApiKey() -> String? {
        if let envKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] {
            return envKey
        }
        
        let envPath = ".env"
        guard let envContent = try? String(contentsOfFile: envPath, encoding: .utf8) else {
            return nil
        }
        
        for line in envContent.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("GEMINI_API_KEY=") {
                let key = String(trimmed.dropFirst("GEMINI_API_KEY=".count))
                return key.isEmpty ? nil : key
            }
        }
        
        return nil
    }
    
    static func main() async {
        guard let apiKey = loadApiKey() else {
            print("❌ GEMINI_API_KEY not found")
            print("💡 Set environment variable or create .env file")
            exit(1)
        }
        
        print("🚀 Starting Gemini Live API test...")
        print("🔑 API Key loaded successfully")
        
        // Initialize GeminiTTS with 15% faster playback
        let tts = GeminiTTS(apiKey: apiKey, playbackSpeed: 1.15)
        
        // Test placeholder text
        let placeholderText = "This is a placeholder text that should be read out loud by the AI voice assistant."
        
        print("📤 Text sent for speech synthesis (1.15x speed)")
        
        do {
            try await tts.synthesizeSpeech(placeholderText)
            print("✅ Text-to-speech test successful!")
        } catch {
            print("❌ Error: \(error)")
            exit(1)
        }
        
        print("🔌 Connection closed")
    }
}