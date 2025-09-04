import Foundation
import SharedModels

@main
struct TestAudioCollector {
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
        
        print("🚀 Testing Gemini Audio Collector...")
        print("🔑 API Key loaded successfully")
        
        let collector = GeminiAudioCollector(apiKey: apiKey)
        let testText = "This is a test of the audio chunk collector component."
        
        print("📤 Starting audio collection for: '\(testText)'")
        
        do {
            var chunkCount = 0
            var totalBytes = 0
            
            for try await audioChunk in collector.collectAudioChunks(from: testText) {
                chunkCount += 1
                totalBytes += audioChunk.count
                print("📦 Chunk \(chunkCount): \(audioChunk.count) bytes (Total: \(totalBytes) bytes)")
                
                // Save all chunks for analysis
                let filename = "/tmp/audio_chunk_\(chunkCount).pcm"
                try audioChunk.write(to: URL(fileURLWithPath: filename))
                print("💾 Saved chunk \(chunkCount) to \(filename)")
                
                // Quick amplitude check
                let samples = audioChunk.withUnsafeBytes { bytes in
                    Array(bytes.bindMemory(to: Int16.self))
                }
                let maxAmplitude = samples.map { Int(abs($0)) }.max() ?? 0
                let audible = maxAmplitude > 1000 ? "🔊" : "🔇"
                print("   Max amplitude: \(maxAmplitude) \(audible)")
            }
            
            print("✅ Audio collection test completed!")
            print("📊 Summary: \(chunkCount) chunks, \(totalBytes) total bytes")
            
        } catch {
            print("❌ Error during audio collection: \(error)")
            exit(1)
        }
    }
}