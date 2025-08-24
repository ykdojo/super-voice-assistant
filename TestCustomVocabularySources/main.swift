import Foundation
import WhisperKit

@main
struct TestCustomVocabulary {
    static func main() async {
        print("🎯 WhisperKit Custom Vocabulary - Production Implementation")
        print("========================================================")
        print("Testing: Space-separated vocabulary with prefix cleaning")
        
        do {
            print("\n📥 Loading model...")
            let whisperKit = try await WhisperKit(model: "openai_whisper-large-v3-v20240930")
            try await whisperKit.loadModels()
            
            guard whisperKit.tokenizer != nil else {
                print("❌ Error: No tokenizer available")
                return
            }
            
            let audioFilePath = "/Users/ykdojo/Desktop/projects/super-voice-assistant/claude.wav"
            let vocabulary = "CLAUDE.md Claude Code"
            
            // Test baseline vs vocabulary
            print("\n🔍 Running transcriptions...")
            let baseline = await transcribe(whisperKit, audioFilePath, vocabulary: nil)
            let enhanced = await transcribe(whisperKit, audioFilePath, vocabulary: vocabulary)
            
            // Results
            print("\n📊 Results:")
            print("   Baseline: '\(baseline)'")
            print("   Enhanced: '\(enhanced)'")
            
            // Quick analysis
            let improved = enhanced != baseline && 
                          enhanced.contains("Claude") && 
                          !enhanced.hasPrefix(vocabulary)
            print("\n✅ Success: \(improved ? "Perfect vocabulary enhancement!" : "Needs investigation")")
            
        } catch {
            print("❌ Error: \(error)")
        }
    }
    
    /// Production-ready transcription with optional vocabulary
    static func transcribe(_ whisperKit: WhisperKit, _ audioPath: String, vocabulary: String?) async -> String {
        guard let tokenizer = whisperKit.tokenizer else { return "No tokenizer" }
        
        var options = DecodingOptions(skipSpecialTokens: true)
        
        if let vocab = vocabulary, !vocab.isEmpty {
            let prefixTokens = tokenizer.encode(text: " \(vocab)").filter { 
                $0 < tokenizer.specialTokens.specialTokenBegin 
            }
            options.prefixTokens = prefixTokens
        }
        
        do {
            let result = try await whisperKit.transcribe(audioPath: audioPath, decodeOptions: options)
            let transcript = result.first?.text ?? ""
            
            // Clean prefix if vocabulary was used
            if let vocab = vocabulary, !vocab.isEmpty, transcript.hasPrefix(vocab) {
                let patterns = [vocab + ": ", vocab + ". ", vocab + " ", vocab]
                for pattern in patterns {
                    if transcript.hasPrefix(pattern) {
                        return String(transcript.dropFirst(pattern.count)).trimmingCharacters(in: .whitespaces)
                    }
                }
            }
            
            return transcript
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
}
