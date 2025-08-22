import Foundation
import WhisperKit

// Test program to explore WhisperKit tokenizer capabilities

struct TokenizerExplorer {
    static func main() async {
        print("🔍 WhisperKit Tokenizer Exploration")
        print("=" + String(repeating: "=", count: 40))
        
        // Try to initialize WhisperKit with a model
        let modelName = "openai_whisper-tiny"
        let modelPath = URL(fileURLWithPath: "/Users/yk/Documents/huggingface/models/argmaxinc/whisperkit-coreml/\(modelName)")
        
        print("\n📁 Model path: \(modelPath.path)")
        print("⏳ Loading WhisperKit...")
        
        do {
            // Initialize WhisperKit
            let whisperKit = try await WhisperKit(
                modelFolder: modelPath.path,
                verbose: false,
                logLevel: .error,
                load: true
            )
            
            print("✅ WhisperKit loaded successfully")
            
            // Try to access tokenizer
            print("\n🔤 Checking for tokenizer access...")
            
            // Use Mirror to inspect available properties
            let mirror = Mirror(reflecting: whisperKit)
            print("\n📋 Available properties on WhisperKit instance:")
            for child in mirror.children {
                if let propertyName = child.label {
                    print("  • \(propertyName): \(type(of: child.value))")
                }
            }
            
            // Try to access specific tokenizer-related properties
            // This will help us understand what's available
            
            // Check if there's a textDecoder property
            if let textDecoder = mirror.children.first(where: { $0.label == "textDecoder" }) {
                print("\n✅ Found textDecoder property!")
                let decoderMirror = Mirror(reflecting: textDecoder.value)
                print("  TextDecoder properties:")
                for child in decoderMirror.children {
                    if let propertyName = child.label {
                        print("    • \(propertyName): \(type(of: child.value))")
                    }
                }
            }
            
            // Check for tokenizer property
            if let tokenizer = mirror.children.first(where: { $0.label == "tokenizer" }) {
                print("\n✅ Found tokenizer property!")
                let tokenizerMirror = Mirror(reflecting: tokenizer.value)
                print("  Tokenizer properties:")
                for child in tokenizerMirror.children {
                    if let propertyName = child.label {
                        print("    • \(propertyName): \(type(of: child.value))")
                    }
                }
            }
            
            // Test encoding if we can find a way
            let testText = "Hello, this is a test of custom vocabulary."
            print("\n🧪 Test text: \"\(testText)\"")
            
            // Try to encode text using the tokenizer
            print("\n📊 Attempting to encode text...")
            
            // Attempt 1: Direct tokenizer access
            if let tokenizer = whisperKit.tokenizer {
                print("✅ Got tokenizer reference")
                
                // Try encoding
                let tokens = tokenizer.encode(text: testText)
                print("✅ Encoded tokens: \(tokens)")
                print("   Token count: \(tokens.count)")
                
                // Try decoding to verify
                let decoded = tokenizer.decode(tokens: tokens)
                print("✅ Decoded text: \"\(decoded)\"")
                
                // Test with some technical vocabulary
                let technicalText = "API JSON HTTP REST GraphQL WebSocket"
                let technicalTokens = tokenizer.encode(text: technicalText)
                print("\n🔬 Technical vocabulary test:")
                print("   Text: \"\(technicalText)\"")
                print("   Tokens: \(technicalTokens)")
                print("   Token count: \(technicalTokens.count)")
                
                // Try encoding a prompt-like text that could be used with promptTokens
                let promptText = "The following is a technical discussion about software development. Terms like API, JSON, and GraphQL are common."
                let promptTokens = tokenizer.encode(text: promptText)
                print("\n💡 Prompt tokens example:")
                print("   Text: \"\(promptText)\"")
                print("   Tokens (first 20): \(Array(promptTokens.prefix(20)))")
                print("   Total token count: \(promptTokens.count)")
                
                // These tokens could be used in DecodingOptions.promptTokens!
                print("\n✨ Success! These tokens can be used with DecodingOptions.promptTokens parameter")
            } else {
                print("❌ Could not access tokenizer")
            }
            
            print("\n🔍 Investigation complete!")
            
        } catch {
            print("❌ Failed to load WhisperKit: \(error)")
        }
    }
}

// Run the async main function
Task {
    await TokenizerExplorer.main()
    exit(0)
}

// Keep the program running
RunLoop.main.run()