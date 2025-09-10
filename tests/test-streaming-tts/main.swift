import Foundation
import SharedModels

@main
struct TestStreamingTTS {
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
        
        print("🚀 Testing End-to-End Streaming TTS...")
        print("🔑 API Key loaded successfully")
        
        let collector = GeminiAudioCollector(apiKey: apiKey)
        let player = GeminiStreamingPlayer(playbackSpeed: 1.15)
        
        let testText = "This is a test of streaming text-to-speech. You should hear this audio playing as chunks arrive in real-time."
        
        print("📤 Starting streaming TTS for: '\(testText)'")
        print("🎵 Audio should start playing as soon as first chunk arrives...")
        
        do {
            // Get the audio stream from collector and immediately play it
            let audioStream = collector.collectAudioChunks(from: testText)
            try await player.playAudioStream(audioStream)
            
            print("✅ Streaming TTS test completed successfully!")
            
        } catch {
            print("❌ Error during streaming TTS: \(error)")
            exit(1)
        }
        
        player.stopAudioEngine()
        print("🔌 Audio engine stopped")
    }
}