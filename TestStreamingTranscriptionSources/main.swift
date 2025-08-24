import Foundation
import AVFoundation
import WhisperKit
import SharedModels
import Dispatch
import AppKit

@MainActor
class StreamingTranscriptionTest {
    private var whisperKit: WhisperKit?
    private var audioStreamTranscriber: AudioStreamTranscriber?
    private var isStreaming = false
    
    // Track confirmed segments and current text separately
    private var confirmedSegments: [String] = []
    private var lastDisplayedText = ""
    private var maxTextLengthSeen = 0  // Prevent display from getting shorter
    private var lastUpdateTime: Date = Date()
    
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
    
    func loadWhisperModel(modelName: String) async throws {
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
            requiredSegmentsForConfirmation: 0,  // Confirm segments faster
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
        
        print("🎤 Starting transcription... (press Ctrl+C to copy current text to clipboard)")
        
        isStreaming = true
        
        try await transcriber.startStreamTranscription()
    }
    
    func stopStreaming() async {
        guard let transcriber = audioStreamTranscriber else { return }
        
        // Clear the streaming line before showing final output
        print("\r\u{001B}[K", terminator: "")
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
                    // Don't show confirmed segments anymore per user request
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
        // Also add throttling to prevent rapid updates and exact duplicate checking
        let now = Date()
        let timeSinceLastUpdate = now.timeIntervalSince(lastUpdateTime)
        
        if fullText.count >= lastDisplayedText.count && 
           !fullText.isEmpty && 
           fullText != lastDisplayedText && 
           timeSinceLastUpdate > 0.1 {  // Throttle updates to max 10 per second
            
            lastDisplayedText = fullText
            maxTextLengthSeen = max(maxTextLengthSeen, fullText.count)
            lastUpdateTime = now
            displayStreamingText(fullText)
        }
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
    
    private func displayStreamingText(_ text: String) {
        // Clear the entire line first, then display new text
        print("\r\u{001B}[K📝 \(text)", terminator: "")
        fflush(stdout)  // Force immediate display
    }
    
    func copyCurrentTextToClipboard() {
        let textToCopy = lastDisplayedText.isEmpty ? "(No speech detected)" : lastDisplayedText
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(textToCopy, forType: .string)
        
        // Clear the current transcription state for fresh start
        confirmedSegments.removeAll()
        lastDisplayedText = ""
        maxTextLengthSeen = 0
        lastUpdateTime = Date()
        
        // Clear the streaming line and show copy confirmation
        print("\r\u{001B}[K📋 Copied to clipboard: \(textToCopy)")
        print("🎤 Ready for new transcription... (press Ctrl+C to copy current text)")
    }
}

@main
struct TestStreamingTranscription {
    static func main() async {
        print("🎙️  Streaming Transcription Test")
        print(String(repeating: "=", count: 35))
        
        let test = StreamingTranscriptionTest()
        
        // Set up a signal source for Ctrl+C
        let sigintSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        
        signal(SIGINT, SIG_IGN) // Ignore default handler

        sigintSource.setEventHandler {
            print("\n📋 Ctrl+C pressed - copying current text to clipboard...")
            Task {
                test.copyCurrentTextToClipboard()
            }
        }
        sigintSource.resume()

        // Determine model from command-line arguments
        let useLargeModel = CommandLine.arguments.contains("--large")
        let modelName = useLargeModel ? "openai_whisper-large-v3-v20240930" : "openai_whisper-tiny"

        if useLargeModel {
            print("✅ Using large model specified by --large flag.")
        } else {
            print("✅ Using default tiny model. Pass --large to use the large model.")
        }

        do {
            // Check microphone permission
            let hasPermission = await test.requestMicrophonePermission()
            
            guard hasPermission else {
                print("❌ Microphone permission required")
                exit(1)
            }
            
            // Load model and setup
            try await test.loadWhisperModel(modelName: modelName)
            try await test.setupStreamTranscriber()
            
            // Start streaming
            try await test.startStreaming()
            
            // Keep the program running indefinitely
            print("🔄 Transcription running continuously. Press Ctrl+C to copy current text to clipboard.")
            
            // Use a different approach to keep the program running
            while true {
                try await Task.sleep(nanoseconds: 1_000_000_000) // Sleep for 1 second
            }
            
        } catch {
            print("❌ Error: \(error)")
            await test.stopStreaming()
            exit(1)
        }
    }
}

