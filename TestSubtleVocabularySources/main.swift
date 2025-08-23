import Foundation
import WhisperKit

@main
struct TestSubtleVocabulary {
    static func main() async {
        print("=== Testing Subtle Custom Vocabulary for Natural Transcription ===")
        print("Target: 'I want to put this in CLAUDE.md using Claude Code.'")
        
        do {
            print("1. Loading model...")
            let whisperKit = try await WhisperKit(model: "openai_whisper-large-v3-v20240930")
            try await whisperKit.loadModels()
            
            guard let tokenizer = whisperKit.tokenizer else {
                print("❌ No tokenizer available")
                return
            }
            
            let audioFilePath = "/Users/ykdojo/Desktop/projects/super-voice-assistant/claude.wav"
            
            // Test different subtle vocabulary approaches
            let strategies = [
                ("Minimal hint", " Claude"),
                ("Just filename", " CLAUDE.md"),
                ("Just the name", " Claude Code"),
                ("File and tool", " CLAUDE.md Claude Code"),
                ("Context hint", " software development with Claude"),
                ("Empty prefix", "")
            ]
            
            print("2. Testing different vocabulary strategies:")
            
            for (name, prefixText) in strategies {
                print("\n--- \(name) Strategy ---")
                print("   - Prefix: '\(prefixText)'")
                
                let options: DecodingOptions
                
                if prefixText.isEmpty {
                    // Test with promptTokens instead of prefixTokens
                    let vocabTokens = tokenizer.encode(text: "Claude Code CLAUDE.md").filter { 
                        $0 < tokenizer.specialTokens.specialTokenBegin 
                    }
                    options = DecodingOptions(
                        skipSpecialTokens: true,
                        promptTokens: vocabTokens
                    )
                    print("   - Using promptTokens: \(vocabTokens)")
                } else {
                    let prefixTokens = tokenizer.encode(text: prefixText).filter { 
                        $0 < tokenizer.specialTokens.specialTokenBegin 
                    }
                    options = DecodingOptions(
                        skipSpecialTokens: true,
                        prefixTokens: prefixTokens
                    )
                    print("   - Tokens: \(prefixTokens)")
                }
                
                let result = try await whisperKit.transcribe(audioPath: audioFilePath, decodeOptions: options)
                let transcript = result.first?.text ?? "No transcription"
                
                print("   - Result: '\(transcript)'")
                
                // Check how close we are to target
                let hasCorrectStructure = transcript.contains("I want to put this in") && transcript.contains("using")
                let hasClaude = transcript.contains("Claude")
                let hasCLAUDEmd = transcript.contains("CLAUDE.md")
                let hasClaudeCode = transcript.contains("Claude Code")
                let isEmpty = transcript.isEmpty || transcript == "No transcription"
                
                print("   - Analysis:")
                print("     • Correct structure: \(hasCorrectStructure ? "✅" : "❌")")
                print("     • Has 'Claude': \(hasClaude ? "✅" : "❌")")
                print("     • Has 'CLAUDE.md': \(hasCLAUDEmd ? "✅" : "❌")")
                print("     • Has 'Claude Code': \(hasClaudeCode ? "✅" : "❌")")
                print("     • Not empty: \(!isEmpty ? "✅" : "❌")")
                
                if hasCorrectStructure && hasClaude && (hasCLAUDEmd || hasClaudeCode) {
                    print("   🎯 EXCELLENT: Natural transcription with correct vocabulary!")
                } else if hasCorrectStructure && hasClaude {
                    print("   ✅ GOOD: Natural transcription with some vocabulary improvement")
                } else if hasClaude && !isEmpty {
                    print("   ⚠️  PARTIAL: Has vocabulary but wrong structure")
                } else if !isEmpty {
                    print("   ⚠️  BASIC: Transcription works but no vocabulary improvement")
                } else {
                    print("   ❌ FAILED: Empty transcription")
                }
            }
            
            // Baseline for comparison
            print("\n--- Baseline (no vocabulary) ---")
            let baselineOptions = DecodingOptions(skipSpecialTokens: true)
            let baselineResult = try await whisperKit.transcribe(audioPath: audioFilePath, decodeOptions: baselineOptions)
            let baselineTranscript = baselineResult.first?.text ?? "No transcription"
            print("   - Baseline: '\(baselineTranscript)'")
            
        } catch {
            print("❌ Error: \(error)")
        }
        
        print("\n=== Test Complete ===")
    }
}
