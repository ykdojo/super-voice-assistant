import Foundation
import WhisperKit

@main
struct TestVocabularyModels {
    static func main() async {
        print("🎯 WhisperKit Custom Vocabulary - Multi-Model Test")
        print("=================================================")
        print("Testing custom vocabulary across all available models")
        
        let models = [
            ("openai_whisper-tiny", "Tiny"),
            ("distil-whisper_distil-large-v3", "Distil-Whisper V3"),
            ("openai_whisper-large-v3-v20240930_turbo", "Large V3 Turbo"),
            ("openai_whisper-large-v3-v20240930", "Large V3")
        ]
        
        let audioFilePath = "/Users/ykdojo/Desktop/projects/super-voice-assistant/claude.wav"
        let vocabulary = "CLAUDE.md Claude Code"
        
        print("\n🎵 Audio: 'I want to put this in CLAUDE.md using Claude Code'")
        print("📝 Vocabulary: '\(vocabulary)'")
        print("=" * 60)
        
        for (modelName, displayName) in models {
            print("\n🔍 Testing \(displayName) (\(modelName))")
            print("-" * 50)
            
            do {
                print("📥 Loading model...")
                let whisperKit = try await WhisperKit(model: modelName)
                try await whisperKit.loadModels()
                
                guard whisperKit.tokenizer != nil else {
                    print("❌ Error: No tokenizer available for this model")
                    continue
                }
                
                print("🎯 Running transcriptions...")
                let baseline = await transcribe(whisperKit, audioFilePath, vocabulary: nil)
                let enhanced = await transcribe(whisperKit, audioFilePath, vocabulary: vocabulary)
                
                // Results
                print("📊 Results:")
                print("   Baseline: '\(baseline)'")
                print("   Enhanced: '\(enhanced)'")
                
                // Analysis
                let hasClaudeCorrect = enhanced.lowercased().contains("claude") && !enhanced.lowercased().contains("cloud")
                let hasMdCorrect = enhanced.contains(".md")
                let isCleanOutput = !enhanced.hasPrefix(vocabulary)
                let improved = enhanced != baseline
                
                let score = [hasClaudeCorrect, hasMdCorrect, isCleanOutput, improved].filter { $0 }.count
                let status = score >= 3 ? "✅ Excellent" : score >= 2 ? "⚠️  Good" : "❌ Poor"
                
                print("🎯 Quality Score: \(score)/4 - \(status)")
                if hasClaudeCorrect { print("   ✅ 'Claude' recognized correctly") }
                if hasMdCorrect { print("   ✅ '.md' preserved") }
                if isCleanOutput { print("   ✅ Clean output (no prefix)") }
                if improved { print("   ✅ Enhancement detected") }
                
            } catch {
                print("❌ Error loading \(displayName): \(error.localizedDescription)")
            }
        }
        
        print("\n" + "=" * 60)
        print("✨ Multi-model test complete!")
        print("💡 Best models will have scores of 4/4 with 'Excellent' rating")
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

// String extension for repeating characters
extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}
