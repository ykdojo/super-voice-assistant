import Foundation
import AVFoundation
import WhisperKit
import SharedModels

@MainActor
class StreamingTranscriptionTest {
    private var whisperKit: WhisperKit?
    private var audioStreamTranscriber: AudioStreamTranscriber?
    private var isStreaming = false
    
    // Track confirmed segments and current text separately
    private var confirmedSegments: [String] = []
    private var lastDisplayedText = ""
    private var maxTextLengthSeen = 0  // Prevent display from getting shorter
    
    init() {
        print("🎯 Streaming Transcription Test")
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
        
        print("✅ Model loaded")
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
            requiredSegmentsForConfirmation: 1,  // Confirm segments faster
            silenceThreshold: 0.2,  // More sensitive to detect speech breaks
            compressionCheckWindow: 60,
            useVAD: true,  // Enable voice activity detection
            stateChangeCallback: { [weak self] oldState, newState in
                Task { [weak self] in
                    self?.handleStateChange(oldState: oldState, newState: newState)
                }
            }
        )
        
        print("✅ Transcriber ready")
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
        
        print("🎤 Starting transcription... (press Ctrl+C to stop)")
        
        isStreaming = true
        
        try await transcriber.startStreamTranscription()
    }
    
    func stopStreaming() async {
        guard let transcriber = audioStreamTranscriber else { return }
        
        print("🛑 Stopping...")
        await transcriber.stopStreamTranscription()
        isStreaming = false
        
        print("\n" + String(repeating: "=", count: 50))
        print("🏁 FINAL TRANSCRIPTION")
        print(String(repeating: "=", count: 50))
        if !lastDisplayedText.isEmpty {
            print(lastDisplayedText)
        } else {
            print("(No speech detected)")
        }
        print(String(repeating: "=", count: 50))
    }
    
    private func handleStateChange(oldState: AudioStreamTranscriber.State, newState: AudioStreamTranscriber.State) {
        // Handle newly confirmed segments
        if newState.confirmedSegments.count > oldState.confirmedSegments.count {
            let newSegments = Array(newState.confirmedSegments.suffix(newState.confirmedSegments.count - oldState.confirmedSegments.count))
            
            for segment in newSegments {
                let segmentText = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !segmentText.isEmpty && isValidSpeechText(segmentText) {
                    confirmedSegments.append(segmentText)
                    print("✅ Confirmed segment: \(segmentText)")
                }
            }
        }
        
        // Get the current unconfirmed text
        let currentText = newState.currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Build the complete text: confirmed segments + current text
        var fullText = ""
        if !confirmedSegments.isEmpty {
            fullText = confirmedSegments.joined(separator: " ")
        }
        if !currentText.isEmpty && isValidSpeechText(currentText) {
            if !fullText.isEmpty {
                fullText += " " + currentText
            } else {
                fullText = currentText
            }
        }
        
        // CRITICAL: Never show shorter text than we've already shown
        // If the new fullText is shorter than what we last displayed, keep showing the last one
        if fullText.count >= lastDisplayedText.count && !fullText.isEmpty {
            lastDisplayedText = fullText
            maxTextLengthSeen = max(maxTextLengthSeen, fullText.count)
            print("📝 \(fullText)")
        }
        // If text got shorter, silently keep the previous text (don't show warning)
    }
    
    private func isValidSpeechText(_ text: String) -> Bool {
        // Filter out only the specific system message we saw
        let lowercaseText = text.lowercased()
        
        // Check for the specific "waiting for speech" message
        if lowercaseText.contains("waiting for speech") {
            return false
        }
        
        return true
    }
}

@main
struct TestStreamingTranscription {
    static func main() async {
        print("🎙️  Streaming Transcription Test")
        print(String(repeating: "=", count: 35))
        
        let test = StreamingTranscriptionTest()
        
        do {
            // Check microphone permission
            let hasPermission = await test.requestMicrophonePermission()
            
            guard hasPermission else {
                print("❌ Microphone permission required")
                exit(1)
            }
            
            // Load model and setup
            try await test.loadWhisperModel()
            try await test.setupStreamTranscriber()
            
            // Start streaming
            try await test.startStreaming()
            
            // Keep running until Ctrl+C
            while true {
                try await Task.sleep(nanoseconds: 1_000_000_000)
            }
            
        } catch {
            print("❌ Error: \(error)")
            await test.stopStreaming()
            exit(1)
        }
    }
}
