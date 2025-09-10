import Foundation
import WhisperKit
import SharedModels

struct TranscriptionTester {
    static let availableModels = [
        ("distil-whisper_distil-large-v3", "Distil-Whisper V3"),
        ("openai_whisper-large-v3-v20240930_turbo", "Large V3 Turbo"),
        ("openai_whisper-large-v3-v20240930", "Large V3"),
        ("openai_whisper-tiny", "Tiny")
    ]
    
    static func printUsage() {
        print("""
        🎤 WhisperKit Transcription Test Tool
        =====================================
        
        Usage: TestTranscription <audio_file> [options]
        
        Options:
            --model <model_name>    Use specific model (e.g., openai_whisper-tiny)
            --all                   Run transcription with all available models
            --list                  List available models
            --verbose               Show detailed output
            --help                  Show this help message
        
        Available models:
        """)
        for (modelName, displayName) in availableModels {
            print("  • \(modelName) - \(displayName)")
        }
        print("""
        
        Examples:
            TestTranscription audio.wav --model openai_whisper-tiny
            TestTranscription recording.m4a --all
            TestTranscription --list
        """)
    }
    
    static func listModels() {
        let modelManager = WhisperModelManager.shared
        
        print("🔍 Checking available models...")
        print("================================\n")
        
        for (modelName, displayName) in availableModels {
            print("Model: \(displayName)")
            print("  ID: \(modelName)")
            
            if !modelManager.modelExistsOnDisk(modelName) {
                print("  Status: ❌ Not downloaded")
            } else if modelManager.isModelDownloaded(modelName) {
                print("  Status: ✅ Ready for use")
                if let metadata = modelManager.getModelMetadata(modelName) {
                    if let size = metadata.totalSize {
                        let sizeInMB = Double(size) / 1024 / 1024
                        print("  Size: \(String(format: "%.1f", sizeInMB)) MB")
                    }
                }
            } else {
                print("  Status: ⚠️  Incomplete (needs re-download)")
            }
            print("")
        }
    }
    
    static func transcribeWithModel(audioPath: URL, modelName: String, displayName: String, verbose: Bool) async throws {
        let modelManager = WhisperModelManager.shared
        
        print("\n🎯 Testing \(displayName)")
        print("─" + String(repeating: "─", count: 40))
        
        // Verify model exists and is complete
        print("🔍 Verifying model integrity...")
        
        if !modelManager.modelExistsOnDisk(modelName) {
            print("  ❌ Model directory not found")
            print("     Please download it first using the main app or TestDownload")
            return
        }
        print("  ✓ Model directory exists")
        
        if !modelManager.isModelDownloaded(modelName) {
            print("  ⚠️  Model not marked as complete")
            print("  🔧 Attempting validation...")
            
            // Try to load the model to validate it's complete
            let modelPath = modelManager.getModelPath(for: modelName)
            do {
                let _ = try await WhisperKit(
                    modelFolder: modelPath.path,
                    verbose: false,
                    logLevel: .error,
                    load: true
                )
                // If loading succeeds, mark it as complete
                modelManager.markModelAsDownloaded(modelName)
                print("  ✅ Model validated and marked as complete")
            } catch {
                print("  ❌ Model validation failed. Please re-download.")
                print("     Error: \(error.localizedDescription)")
                return
            }
        } else {
            print("  ✓ Model verified and ready")
        }
        
        // Get model path
        let modelPath = modelManager.getModelPath(for: modelName).path
        
        if verbose {
            print("📁 Model path: \(modelPath)")
            print("🎵 Audio file: \(audioPath.lastPathComponent)")
        }
        
        print("⏳ Loading model...")
        
        do {
            // Initialize WhisperKit with the specific model
            let whisperKit = try await WhisperKit(
                modelFolder: modelPath,
                verbose: verbose,
                logLevel: verbose ? .debug : .error
            )
            
            print("✅ Model loaded successfully")
            print("🎙️ Starting transcription...")
            
            let startTime = Date()
            
            // Perform transcription
            let results = try await whisperKit.transcribe(
                audioPath: audioPath.path,
                decodeOptions: DecodingOptions(
                    verbose: verbose,
                    task: .transcribe,
                    language: "en",
                    temperature: 0.0,
                    temperatureFallbackCount: 5,
                    sampleLength: 224,
                    topK: 5,
                    usePrefillPrompt: true,
                    usePrefillCache: true,
                    skipSpecialTokens: true,
                    withoutTimestamps: false,
                    clipTimestamps: [0],
                    suppressBlank: true,
                    supressTokens: nil
                )
            )
            
            let endTime = Date()
            let processingTime = endTime.timeIntervalSince(startTime)
            
            // Extract and display results
            if let transcription = results.first?.text {
                print("✅ Transcription complete!")
                print("⏱️ Processing time: \(String(format: "%.2f", processingTime)) seconds")
                print("\n📝 Transcription:")
                print("─" + String(repeating: "─", count: 40))
                print(transcription)
                print("─" + String(repeating: "─", count: 40))
                
                // Show segments if verbose
                if verbose, let segments = results.first?.segments {
                    print("\n📊 Segments (\(segments.count) total):")
                    for (index, segment) in segments.enumerated() {
                        let start = String(format: "%.2f", segment.start)
                        let end = String(format: "%.2f", segment.end)
                        print("  [\(index + 1)] \(start)s - \(end)s: \(segment.text)")
                    }
                }
            } else {
                print("⚠️  No transcription result returned")
            }
            
        } catch {
            print("❌ Transcription failed: \(error.localizedDescription)")
            if verbose {
                print("Error details: \(error)")
            }
        }
    }
    
    static func main() async {
        let arguments = CommandLine.arguments
        
        // Check for help or no arguments
        if arguments.count < 2 || arguments.contains("--help") || arguments.contains("-h") {
            printUsage()
            exit(0)
        }
        
        // Check for list command
        if arguments.contains("--list") {
            listModels()
            exit(0)
        }
        
        // Parse arguments
        let audioPath: URL
        var selectedModel: String?
        var runAll = false
        var verbose = false
        
        // First argument after program name should be audio file
        let audioPathString = arguments[1]
        
        // Check if file exists
        let fileManager = FileManager.default
        if audioPathString.starts(with: "-") {
            print("❌ Error: First argument must be an audio file path")
            print("   Use --help for usage information")
            exit(1)
        }
        
        // Convert to absolute path if needed
        if audioPathString.starts(with: "/") {
            audioPath = URL(fileURLWithPath: audioPathString)
        } else {
            let currentDirectory = fileManager.currentDirectoryPath
            audioPath = URL(fileURLWithPath: currentDirectory).appendingPathComponent(audioPathString)
        }
        
        // Verify file exists
        if !fileManager.fileExists(atPath: audioPath.path) {
            print("❌ Error: Audio file not found: \(audioPath.path)")
            exit(1)
        }
        
        // Parse options
        var i = 2
        while i < arguments.count {
            let arg = arguments[i]
            
            switch arg {
            case "--model":
                if i + 1 < arguments.count {
                    selectedModel = arguments[i + 1]
                    i += 1
                } else {
                    print("❌ Error: --model requires a model name")
                    exit(1)
                }
                
            case "--all":
                runAll = true
                
            case "--verbose", "-v":
                verbose = true
                
            default:
                print("⚠️  Unknown option: \(arg)")
            }
            
            i += 1
        }
        
        // Validate options
        if runAll && selectedModel != nil {
            print("⚠️  Warning: --all flag overrides --model selection")
            selectedModel = nil
        }
        
        // Default to running all models if no specific selection
        if !runAll && selectedModel == nil {
            print("ℹ️  No model specified, defaulting to --all")
            runAll = true
        }
        
        print("🎤 WhisperKit Transcription Test")
        print("=" + String(repeating: "=", count: 40))
        print("📁 Audio file: \(audioPath.lastPathComponent)")
        print("📍 Full path: \(audioPath.path)")
        
        // Get file info
        if let attributes = try? fileManager.attributesOfItem(atPath: audioPath.path),
           let fileSize = attributes[.size] as? Int64 {
            let sizeInMB = Double(fileSize) / 1024 / 1024
            print("💾 File size: \(String(format: "%.2f", sizeInMB)) MB")
        }
        
        // Run transcription
        if runAll {
            print("\n🚀 Running transcription with all available models...")
            
            for (modelName, displayName) in availableModels {
                do {
                    try await transcribeWithModel(
                        audioPath: audioPath,
                        modelName: modelName,
                        displayName: displayName,
                        verbose: verbose
                    )
                } catch {
                    print("❌ Failed to transcribe with \(displayName): \(error)")
                }
            }
            
            print("\n✨ All transcriptions complete!")
            
        } else if let modelName = selectedModel {
            // Find display name for selected model
            var displayName = modelName
            for (name, display) in availableModels {
                if name == modelName {
                    displayName = display
                    break
                }
            }
            
            print("\n🚀 Running transcription with \(displayName)...")
            
            do {
                try await transcribeWithModel(
                    audioPath: audioPath,
                    modelName: modelName,
                    displayName: displayName,
                    verbose: verbose
                )
                print("\n✨ Transcription complete!")
            } catch {
                print("❌ Transcription failed: \(error)")
                exit(1)
            }
        }
    }
}

// Run the async main function
Task {
    await TranscriptionTester.main()
    exit(0)
}

// Keep the program running
RunLoop.main.run()