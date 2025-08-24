import Foundation
import AVFoundation
import WhisperKit
import SharedModels

@MainActor
class StreamingTranscriptionTest {
    private var whisperKit: WhisperKit?
    private var audioStreamTranscriber: AudioStreamTranscriber?
    private var isStreaming = false
    
    // Track streaming results
    private var allConfirmedText: String = ""
    private var currentUnconfirmedText: String = ""
    private var lastProgressText: String = ""
    private var lastDisplayedLiveText: String = ""  // Track what we actually displayed
    private var isShowingProgress: Bool = false
    
    init() {
        print("🎯 Streaming Transcription Test")
        print("This test will continuously transcribe your speech in real-time chunks")
    }
    
    // MARK: - Terminal UI Helpers
    
    private func clearCurrentLine() {
        print("\r\u{001B}[K", terminator: "")
        fflush(stdout)
    }
    
    private func updateProgressLine(_ text: String) {
        // Only update if the text has actually changed
        if text != lastProgressText {
            clearCurrentLine()
            print("🔄 \(text)", terminator: "")
            fflush(stdout)
            isShowingProgress = true
            lastProgressText = text
        }
    }
    
    private func printConfirmed(_ text: String) {
        if isShowingProgress {
            clearCurrentLine()
            isShowingProgress = false
            lastProgressText = ""
        }
        print("✅ \(text)")
        fflush(stdout)
    }
    
    private func printUnconfirmed(_ text: String) {
        if isShowingProgress {
            clearCurrentLine()
            isShowingProgress = false
            lastProgressText = ""
        }
        print("⏳ \(text)")
        fflush(stdout)
    }
    
    private func printStatus(_ text: String) {
        if isShowingProgress {
            clearCurrentLine()
            isShowingProgress = false
            lastProgressText = ""
        }
        print("🔇 \(text)")
        fflush(stdout)
    }
    
    func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    func loadWhisperModel() async throws {
        // Use a smaller, faster model for real-time streaming
        let modelName = "openai_whisper-tiny"
        let modelManager = WhisperModelManager.shared
        
        print("📦 Loading WhisperKit with model: \(modelName)")
        
        let modelPath = modelManager.getModelPath(for: modelName)
        if !modelManager.isModelDownloaded(modelName) {
            throw NSError(domain: "TestStreamingTranscription", code: 1, 
                         userInfo: [NSLocalizedDescriptionKey: "Model \(modelName) is not downloaded. Please run: swift run TestDownload"])
        }
        
        whisperKit = try await WhisperKit(
            modelFolder: modelPath.path,
            verbose: false,
            logLevel: .error
        )
        
        print("✅ WhisperKit loaded successfully")
    }
    
    func setupStreamTranscriber() async throws {
        guard let whisperKit = whisperKit else {
            throw NSError(domain: "TestStreamingTranscription", code: 2, 
                         userInfo: [NSLocalizedDescriptionKey: "WhisperKit not initialized"])
        }
        
        // Create audio processor for streaming
        let audioProcessor = AudioProcessor()
        
        // Configure streaming options for real-time transcription
        let decodingOptions = DecodingOptions(
            verbose: false,
            task: .transcribe,
            language: "en",
            temperature: 0.0,
            temperatureFallbackCount: 2,
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
        
        // Create the streaming transcriber with callback for real-time updates
        audioStreamTranscriber = AudioStreamTranscriber(
            audioEncoder: whisperKit.audioEncoder,
            featureExtractor: whisperKit.featureExtractor,
            segmentSeeker: whisperKit.segmentSeeker,
            textDecoder: whisperKit.textDecoder,
            tokenizer: whisperKit.tokenizer!,
            audioProcessor: audioProcessor,
            decodingOptions: decodingOptions,
            requiredSegmentsForConfirmation: 2,  // How many segments to keep unconfirmed
            silenceThreshold: 0.3,  // VAD threshold (0.0 = very sensitive, 1.0 = only loud speech)
            compressionCheckWindow: 60,
            useVAD: true,  // Enable voice activity detection
            stateChangeCallback: { [weak self] oldState, newState in
                Task { [weak self] in
                    self?.handleStateChange(oldState: oldState, newState: newState)
                }
            }
        )
        
        print("🔧 Audio stream transcriber configured")
        print("   - VAD enabled with silence threshold: 0.3")
        print("   - Requires 2 segments for confirmation")
        print("   - Using tiny model for low latency")
    }
    
    func startStreaming() async throws {
        guard let transcriber = audioStreamTranscriber else {
            throw NSError(domain: "TestStreamingTranscription", code: 3, 
                         userInfo: [NSLocalizedDescriptionKey: "Stream transcriber not initialized"])
        }
        
        guard !isStreaming else {
            print("⚠️ Already streaming")
            return
        }
        
        print("\n🎤 Starting continuous streaming transcription...")
        print("💡 Real-time transcription with improved UI:")
        print("   � LIVE: Updates in place as you speak")
        print("   ⏳ DRAFT: Unconfirmed segments (may change)")
        print("   ✅ Final confirmed segments")
        print("🛑 Press Ctrl+C to stop\n")
        
        isStreaming = true
        
        try await transcriber.startStreamTranscription()
    }
    
    func stopStreaming() async {
        guard let transcriber = audioStreamTranscriber else { return }
        
        print("\n🛑 Stopping streaming transcription...")
        await transcriber.stopStreamTranscription()
        isStreaming = false
        
        // Print final summary
        print("\n" + String(repeating: "=", count: 50))
        print("📋 FINAL TRANSCRIPTION SUMMARY")
        print(String(repeating: "=", count: 50))
        if !allConfirmedText.isEmpty {
            print("✅ Confirmed: \(allConfirmedText)")
        }
        if !currentUnconfirmedText.isEmpty {
            print("⏳ Unconfirmed: \(currentUnconfirmedText)")
        }
        if allConfirmedText.isEmpty && currentUnconfirmedText.isEmpty {
            print("❌ No transcription captured")
        }
        print(String(repeating: "=", count: 50))
    }
    
    private func handleStateChange(oldState: AudioStreamTranscriber.State, newState: AudioStreamTranscriber.State) {
        // Handle confirmed segments (these are final and won't change)
        if newState.confirmedSegments.count > oldState.confirmedSegments.count {
            let newSegments = Array(newState.confirmedSegments.suffix(newState.confirmedSegments.count - oldState.confirmedSegments.count))
            for segment in newSegments {
                let segmentText = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !segmentText.isEmpty {
                    allConfirmedText += segmentText + " "
                    printConfirmed("\"\(segmentText)\"")
                }
            }
        }
        
        // Handle unconfirmed segments (these may change as more audio comes in)
        let newUnconfirmedText = newState.unconfirmedSegments.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }.joined(separator: " ")
        
        if newUnconfirmedText != currentUnconfirmedText && !newUnconfirmedText.isEmpty {
            currentUnconfirmedText = newUnconfirmedText
            printUnconfirmed("DRAFT: \"\(newUnconfirmedText)\"")
        }
        
        // Handle real-time progress text (immediate feedback) - update in place
        if newState.currentText != oldState.currentText {
            let progressText = newState.currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            if progressText != "Waiting for speech..." && !progressText.isEmpty {
                updateProgressLine("LIVE: \"\(progressText)\"")
            } else if progressText == "Waiting for speech..." && lastProgressText != progressText {
                printStatus("Waiting for speech... (speak now)")
                lastProgressText = progressText
            }
        }
    }
}

@main
struct TestStreamingTranscription {
    static func main() async {
        print("🎙️  Real-Time Streaming Transcription Test")
        print("==========================================")
        print("This test demonstrates continuous, chunked transcription")
        print("similar to how modern voice assistants work.\n")
        
        let test = StreamingTranscriptionTest()
        
        // Simple approach - let the streaming run until user hits Ctrl+C
        // The operating system will handle the SIGINT signal
        
        do {
            // Check microphone permission
            print("🎤 Requesting microphone permission...")
            let hasPermission = await test.requestMicrophonePermission()
            
            guard hasPermission else {
                print("❌ Microphone permission denied")
                print("Please grant microphone access in System Settings > Privacy & Security > Microphone")
                exit(1)
            }
            print("✅ Microphone permission granted")
            
            // Load model
            print("\n📦 Loading WhisperKit model...")
            try await test.loadWhisperModel()
            
            // Setup transcriber
            print("\n🔧 Setting up streaming transcriber...")
            try await test.setupStreamTranscriber()
            
            // Start streaming
            try await test.startStreaming()
            
            // Keep running - user will press Ctrl+C to stop
            print("🔄 Streaming in progress... Press Ctrl+C to stop")
            while true {
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
            
        } catch {
            print("❌ Error: \(error)")
            await test.stopStreaming()
            exit(1)
        }
        
        print("\n👋 Test completed!")
    }
}
