import Foundation
import WhisperKit

@main
struct TestCleanPrefix {
    static func main() async {
        print("=== Testing Prefix Removal for Clean Transcription ===")
        
        do {
            print("1. Loading model...")
            let whisperKit = try await WhisperKit(model: "openai_whisper-large-v3-v20240930")
            try await whisperKit.loadModels()
            
            guard let tokenizer = whisperKit.tokenizer else {
                print("❌ No tokenizer available")
                return
            }
            
            let audioFilePath = "/Users/ykdojo/Desktop/projects/super-voice-assistant/claude.wav"
            
            // Test the best strategy with post-processing
            let customVocab = " CLAUDE.md Claude Code"
            let prefixTokens = tokenizer.encode(text: customVocab).filter { 
                $0 < tokenizer.specialTokens.specialTokenBegin 
            }
            
            let options = DecodingOptions(
                skipSpecialTokens: true,
                prefixTokens: prefixTokens
            )
            
            print("2. Testing with prefix removal:")
            print("   - Original prefix: '\(customVocab)'")
            
            let result = try await whisperKit.transcribe(audioPath: audioFilePath, decodeOptions: options)
            let rawTranscript = result.first?.text ?? "No transcription"
            print("   - Raw result: '\(rawTranscript)'")
            
            // Post-process to remove the prefix
            let cleanedTranscript = cleanTranscript(rawTranscript, prefix: customVocab.trimmingCharacters(in: .whitespaces))
            print("   - Cleaned result: '\(cleanedTranscript)'")
            
            // Compare with baseline
            print("\n3. Baseline comparison:")
            let baselineOptions = DecodingOptions(skipSpecialTokens: true)
            let baselineResult = try await whisperKit.transcribe(audioPath: audioFilePath, decodeOptions: baselineOptions)
            let baselineTranscript = baselineResult.first?.text ?? "No transcription"
            print("   - Baseline: '\(baselineTranscript)'")
            
            // Analysis
            print("\n4. Analysis:")
            let hasCorrectTerms = cleanedTranscript.contains("Claude") && (cleanedTranscript.contains("CLAUDE.md") || cleanedTranscript.contains("Claude Code"))
            let isClean = !cleanedTranscript.hasPrefix("CLAUDE.md Claude Code:")
            
            print("   - Has correct vocabulary: \(hasCorrectTerms ? "✅" : "❌")")
            print("   - No artificial prefix: \(isClean ? "✅" : "❌")")
            print("   - Better than baseline: \(cleanedTranscript != baselineTranscript ? "✅" : "❌")")
            
        } catch {
            print("❌ Error: \(error)")
        }
    }
    
    static func cleanTranscript(_ transcript: String, prefix: String) -> String {
        // Remove the prefix if it appears at the beginning
        if transcript.hasPrefix(prefix + ":") {
            let withoutPrefix = String(transcript.dropFirst(prefix.count + 1))
            return withoutPrefix.trimmingCharacters(in: .whitespaces)
        } else if transcript.hasPrefix(prefix + ".") {
            let withoutPrefix = String(transcript.dropFirst(prefix.count + 1))
            return withoutPrefix.trimmingCharacters(in: .whitespaces)
        } else if transcript.hasPrefix(prefix) {
            let withoutPrefix = String(transcript.dropFirst(prefix.count))
            return withoutPrefix.trimmingCharacters(in: .whitespaces)
        }
        
        return transcript
    }
}
