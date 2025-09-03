import Foundation

// Minimal Gemini Live API WebSocket Test
// This tests basic connection to Gemini Live API

@main
struct GeminiLiveTest {
    static func loadApiKey() -> String? {
        // Try environment variable first
        if let envKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] {
            return envKey
        }
        
        // Try loading from .env file
        let envPath = ".env"
        guard let envContent = try? String(contentsOfFile: envPath, encoding: .utf8) else {
            return nil
        }
        
        // Parse .env file for GEMINI_API_KEY
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
        // Get API key from environment or .env file
        guard let apiKey = loadApiKey() else {
            print("❌ GEMINI_API_KEY not found")
            print("💡 Set environment variable or create .env file with: GEMINI_API_KEY=your_api_key")
            exit(1)
        }
        
        print("🚀 Starting Gemini Live API connection test...")
        print("🔑 API Key found: \(String(apiKey.prefix(8)))...")
        
        // Create WebSocket URL
        guard let url = URL(string: "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent?key=\(apiKey)") else {
            print("❌ Invalid WebSocket URL")
            exit(1)
        }
        
        print("🌐 Connecting to: \(url.host ?? "unknown")")
        
        // Create WebSocket task
        let session = URLSession.shared
        let webSocketTask = session.webSocketTask(with: url)
        
        // Start connection
        webSocketTask.resume()
        print("🔌 WebSocket connection initiated...")
        
        do {
            // Send initial setup message
            let setupMessage = """
            {
                "setup": {
                    "model": "models/gemini-2.0-flash-live-001",
                    "generation_config": {
                        "response_modalities": ["AUDIO"],
                        "speech_config": {
                            "voice_config": {
                                "prebuilt_voice_config": {
                                    "voice_name": "Aoede"
                                }
                            }
                        }
                    }
                }
            }
            """
            
            try await webSocketTask.send(.string(setupMessage))
            print("📤 Setup message sent")
            
            // Listen for setup response
            let message = try await webSocketTask.receive()
            switch message {
            case .string(let text):
                print("📥 Received response: \(text)")
            case .data(let data):
                print("📥 Received data: \(data.count) bytes")
            @unknown default:
                print("📥 Received unknown message type")
            }
            
            print("✅ Basic WebSocket connection test successful!")
            
        } catch {
            print("❌ WebSocket error: \(error)")
            exit(1)
        }
        
        // Close connection
        webSocketTask.cancel(with: .goingAway, reason: nil)
        print("🔌 Connection closed")
    }
}