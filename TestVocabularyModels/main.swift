import Foundation
import WhisperKit

@main
struct TestVocabularyModels {
    static func main() async {
        print("🎯 WhisperKit Custom Vocabulary - Smart Model Test")
        print("================================================")
        print("Testing with adaptive vocabulary based on model compatibility")
        
        let models = [
            ("openai_whisper-tiny", "Tiny"),
            ("openai_whisper-large-v3-v20240930", "Large V3")
        ]
        
        let audioFilePath = "/Users/ykdojo/Desktop/projects/super-voice-assistant/claude.wav"
        let vocabulary = loadVocabulary()
        
        print("\n🎵 Audio: 'I want to put this in CLAUDE.md using Claude Code'")
        print("📝 Vocabulary: '\(vocabulary)'")
        print("💡 Strategy: Custom vocabulary only for compatible models")
        print("=" * 60)
        
        for (modelName, displayName) in models {
            print("\n🔍 Testing \(displayName) (\(modelName))")
            print("-" * 50)
            
            // Determine if this model supports custom vocabulary
            let supportsVocabulary = isVocabularyCompatible(modelName)
            let strategy = supportsVocabulary ? "Custom Vocabulary" : "Standard Transcription"
            print("🧠 Strategy: \(strategy)")
            
            do {
                print("📥 Loading model...")
                let whisperKit = try await WhisperKit(model: modelName)
                try await whisperKit.loadModels()
                
                guard whisperKit.tokenizer != nil else {
                    print("❌ Error: No tokenizer available for this model")
                    continue
                }
                
                print("🎯 Running transcription...")
                
                // Use vocabulary only for compatible models
                let vocabularyToUse = supportsVocabulary ? vocabulary : nil
                let result = await transcribe(whisperKit, audioFilePath, vocabulary: vocabularyToUse)
                
                // For comparison, also run baseline for vocabulary-compatible models
                if supportsVocabulary {
                    let baseline = await transcribe(whisperKit, audioFilePath, vocabulary: nil)
                    print("📊 Results:")
                    print("   Baseline: '\(baseline)'")
                    print("   Enhanced: '\(result)'")
                    
                    // Analysis for enhanced models
                    let hasClaudeCorrect = result.lowercased().contains("claude") && !result.lowercased().contains("cloud")
                    let hasMdCorrect = result.contains(".md")
                    let isCleanOutput = !result.hasPrefix(vocabulary)
                    let improved = result != baseline
                    
                    let score = [hasClaudeCorrect, hasMdCorrect, isCleanOutput, improved].filter { $0 }.count
                    let status = score >= 3 ? "✅ Excellent" : score >= 2 ? "⚠️  Good" : "❌ Poor"
                    
                    print("🎯 Enhancement Score: \(score)/4 - \(status)")
                    if hasClaudeCorrect { print("   ✅ 'Claude' recognized correctly") }
                    if hasMdCorrect { print("   ✅ '.md' preserved") }
                    if isCleanOutput { print("   ✅ Clean output (no prefix)") }
                    if improved { print("   ✅ Enhancement detected") }
                } else {
                    print("📊 Result: '\(result)'")
                    
                    // Analysis for standard transcription
                    let hasClaudeApprox = result.lowercased().contains("claude") || result.lowercased().contains("cloud")
                    let hasMdApprox = result.lowercased().contains(".md") || result.lowercased().contains("md")
                    
                    print("🎯 Standard Transcription Quality:")
                    if hasClaudeApprox { print("   ✅ Claude/Cloud recognized") }
                    if hasMdApprox { print("   ✅ MD format detected") }
                    print("   💡 Using standard transcription (vocabulary would fail)")
                }
                
            } catch {
                print("❌ Error loading \(displayName): \(error.localizedDescription)")
            }
        }
        
        print("\n" + "=" * 60)
        print("✨ Smart model test complete!")
        print("💡 Vocabulary-compatible models get enhanced transcription")
        print("💡 Incompatible models use reliable standard transcription")
    }
    
    /// Load vocabulary from configuration file
    static func loadVocabulary() -> String {
        let configPath = "/Users/ykdojo/Desktop/projects/super-voice-assistant/vocabulary_config.json"
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: configPath))
            let terms = try JSONDecoder().decode([String].self, from: data)
            return terms.joined(separator: " ")
        } catch {
            print("⚠️  Warning: Could not load vocabulary config, using default")
            return "CLAUDE.md Claude Code"  // Fallback
        }
    }
    
    /// Determines if a model is compatible with custom vocabulary
    /// Based on testing results: Large V3 models work, smaller models fail
    static func isVocabularyCompatible(_ modelName: String) -> Bool {
        let compatibleModels = [
            "openai_whisper-large-v3-v20240930_turbo",  // Large V3 Turbo - RECOMMENDED
            "openai_whisper-large-v3-v20240930"         // Large V3
        ]
        return compatibleModels.contains(modelName)
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
