import Foundation
import WhisperKit
import AVFoundation

// Test program to demonstrate custom vocabulary implementation with WhisperKit

struct VocabularyTest {
    static func main() async {
        print("🎯 WhisperKit Custom Vocabulary Test")
        print("=" + String(repeating: "=", count: 50))
        
        // Use your test audio file path
        let audioPath = "/tmp/test_audio.wav"
        
        // Model to use
        let modelName = "openai_whisper-tiny"
        let modelPath = URL(fileURLWithPath: "/Users/yk/Documents/huggingface/models/argmaxinc/whisperkit-coreml/\(modelName)")
        
        print("\n📁 Model: \(modelName)")
        print("🎵 Audio: \(audioPath)")
        
        // First, let's create a test audio file with some speech
        // For testing, we'll use a simple tone (you should replace with actual speech)
        await createTestAudioFile(at: audioPath)
        
        do {
            // Initialize WhisperKit
            print("\n⏳ Loading WhisperKit...")
            let whisperKit = try await WhisperKit(
                modelFolder: modelPath.path,
                verbose: false,
                logLevel: .error,
                load: true
            )
            
            print("✅ WhisperKit loaded successfully")
            
            // Get the tokenizer
            guard let tokenizer = whisperKit.tokenizer else {
                print("❌ Could not access tokenizer")
                return
            }
            
            // Define custom vocabulary - domain-specific terms
            let customVocabulary = """
            Technical terms: WhisperKit, SwiftUI, macOS, CoreML, API, JSON, HTTP, REST, GraphQL, WebSocket, 
            tokenizer, transcription, AudioTranscriptionManager, ModelStateManager, DecodingOptions.
            Company names: Apple, Anthropic, OpenAI.
            Programming: Swift, Python, JavaScript, TypeScript.
            """
            
            print("\n📝 Custom vocabulary prompt:")
            print("\"" + customVocabulary + "\"")
            
            // Encode the custom vocabulary to tokens
            let promptTokens = tokenizer.encode(text: customVocabulary)
            print("\n🔤 Encoded to \(promptTokens.count) tokens")
            print("First 10 tokens: \(Array(promptTokens.prefix(10)))")
            
            // Test 1: Transcription WITHOUT custom vocabulary
            print("\n" + String(repeating: "─", count: 50))
            print("📊 Test 1: WITHOUT custom vocabulary")
            print(String(repeating: "─", count: 50))
            
            let resultsWithout = try await whisperKit.transcribe(
                audioPath: audioPath,
                decodeOptions: DecodingOptions(
                    verbose: false,
                    task: .transcribe,
                    language: "en",
                    temperature: 0.0,
                    temperatureFallbackCount: 3,
                    sampleLength: 224,
                    topK: 5,
                    usePrefillPrompt: true,
                    usePrefillCache: true,
                    skipSpecialTokens: true,
                    withoutTimestamps: false,
                    suppressBlank: true,
                    supressTokens: nil,
                    promptTokens: nil  // No custom vocabulary
                )
            )
            
            if let text = resultsWithout.first?.text {
                print("📝 Result: \"\(text)\"")
            }
            
            // Test 2: Transcription WITH custom vocabulary
            print("\n" + String(repeating: "─", count: 50))
            print("📊 Test 2: WITH custom vocabulary")
            print(String(repeating: "─", count: 50))
            
            let resultsWith = try await whisperKit.transcribe(
                audioPath: audioPath,
                decodeOptions: DecodingOptions(
                    verbose: false,
                    task: .transcribe,
                    language: "en",
                    temperature: 0.0,
                    temperatureFallbackCount: 3,
                    sampleLength: 224,
                    topK: 5,
                    usePrefillPrompt: true,
                    usePrefillCache: true,
                    skipSpecialTokens: true,
                    withoutTimestamps: false,
                    suppressBlank: true,
                    supressTokens: nil,
                    promptTokens: promptTokens  // WITH custom vocabulary
                )
            )
            
            if let text = resultsWith.first?.text {
                print("📝 Result: \"\(text)\"")
            }
            
            // Test 3: Different prompt strategies
            print("\n" + String(repeating: "─", count: 50))
            print("📊 Test 3: Different prompt strategies")
            print(String(repeating: "─", count: 50))
            
            // Strategy 1: Spelling out acronyms
            let spellingPrompt = "API (A-P-I), JSON (J-S-O-N), HTTP (H-T-T-P)"
            let spellingTokens = tokenizer.encode(text: spellingPrompt)
            print("\n1️⃣ Spelling strategy tokens: \(spellingTokens.count)")
            
            // Strategy 2: Context sentences
            let contextPrompt = "The user is discussing WhisperKit and CoreML. They often mention SwiftUI and macOS development."
            let contextTokens = tokenizer.encode(text: contextPrompt)
            print("2️⃣ Context strategy tokens: \(contextTokens.count)")
            
            // Strategy 3: Example utterances
            let examplePrompt = "I'm using WhisperKit with CoreML. The API returns JSON data."
            let exampleTokens = tokenizer.encode(text: examplePrompt)
            print("3️⃣ Example strategy tokens: \(exampleTokens.count)")
            
            print("\n✨ Demonstration complete!")
            
        } catch {
            print("❌ Error: \(error)")
        }
    }
    
    static func createTestAudioFile(at path: String) async {
        print("\n🎵 Creating test audio file...")
        
        // Create a simple audio file for testing
        // In real usage, you'd use actual speech audio
        let sampleRate = 16000.0
        let duration = 2.0
        let frequency = 440.0
        
        var audioData: [Float] = []
        let sampleCount = Int(sampleRate * duration)
        
        for i in 0..<sampleCount {
            let time = Double(i) / sampleRate
            let sample = Float(sin(2 * .pi * frequency * time) * 0.1)
            audioData.append(sample)
        }
        
        // Convert to audio file (simplified - in production use proper audio APIs)
        // For now, we'll just create an empty file as a placeholder
        FileManager.default.createFile(atPath: path, contents: nil, attributes: nil)
        print("✅ Test audio file created at: \(path)")
    }
}

// Run the async main function
Task {
    await VocabularyTest.main()
    exit(0)
}

// Keep the program running
RunLoop.main.run()