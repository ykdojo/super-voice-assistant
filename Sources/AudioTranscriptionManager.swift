import Foundation
import AVFoundation
import WhisperKit
import AppKit
import SharedModels

protocol AudioTranscriptionManagerDelegate: AnyObject {
    func audioLevelDidUpdate(db: Float)
    func transcriptionDidStart()
    func transcriptionDidComplete(text: String)
    func transcriptionDidFail(error: String)
    func recordingWasCancelled()
}

class AudioTranscriptionManager {
    weak var delegate: AudioTranscriptionManagerDelegate?
    
    // Audio properties
    private var audioEngine: AVAudioEngine!
    private var inputNode: AVAudioInputNode!
    private var audioBuffer: [Float] = []
    private let sampleRate: Double = 16000
    
    // Recording state
    var isRecording = false
    private var escapeKeyMonitor: Any?
    
    // Transcription state
    private var isTranscribing = false
    
    init() {
        setupAudioEngine()
        requestMicrophonePermission()
    }
    
    // MARK: - Custom Vocabulary Support
    
    /// Load vocabulary from configuration file
    private func loadVocabulary() -> String? {
        // Try to find the config file in the app bundle first, then fallback to workspace location
        
        // First try the main bundle
        if let bundlePath = Bundle.main.path(forResource: "vocabulary_config", ofType: "json") {
            return loadVocabularyFromPath(bundlePath)
        }
        
        // Fallback to workspace location (for development)
        let workspacePath = "/Users/ykdojo/Desktop/projects/super-voice-assistant/vocabulary_config.json"
        if FileManager.default.fileExists(atPath: workspacePath) {
            return loadVocabularyFromPath(workspacePath)
        }
        
        return nil
    }
    
    private func loadVocabularyFromPath(_ path: String) -> String? {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let terms = try JSONDecoder().decode([String].self, from: data)
            let joinedTerms = terms.joined(separator: " ")
            return "Custom vocabulary - \(joinedTerms)"
        } catch {
            print("⚠️  Warning: Could not load vocabulary config from \(path): \(error)")
            return nil
        }
    }
    
    /// Determines if a model is compatible with custom vocabulary
    /// Based on testing results: Large V3 models work, smaller models fail
    private func isVocabularyCompatible(_ modelName: String) -> Bool {
        let compatibleModels = [
            "openai_whisper-large-v3-v20240930_turbo",  // Large V3 Turbo - TESTED ✅
            "openai_whisper-large-v3-v20240930"         // Large V3 - TESTED ✅
            // Note: distil-whisper_distil-large-v3 NOT tested yet - may not work due to distillation
        ]
        return compatibleModels.contains(modelName)
    }
    
    /// Clean vocabulary prefix from transcription result
    private func cleanVocabularyPrefix(_ transcript: String, vocabulary: String) -> String {
        // First clean any occurrences anywhere in the text
        var cleaned = cleanVocabularyPatterns(transcript, vocabulary: vocabulary)
        
        // Then also handle prefix removal (original logic)
        guard cleaned.hasPrefix(vocabulary) else { return cleaned }
        
        let patterns = [vocabulary + ": ", vocabulary + ". ", vocabulary + " ", vocabulary]
        for pattern in patterns {
            if cleaned.hasPrefix(pattern) {
                return String(cleaned.dropFirst(pattern.count)).trimmingCharacters(in: .whitespaces)
            }
        }
        return cleaned
    }
    
    /// Clean vocabulary patterns anywhere in the transcription text
    private func cleanVocabularyPatterns(_ transcript: String, vocabulary: String) -> String {
        // Create the main problematic pattern: vocabulary + ": "
        let pattern = vocabulary + ": "
        
        // Remove all occurrences of this pattern anywhere in the text
        let result = transcript.replacingOccurrences(of: pattern, with: "")
        
        return result.trimmingCharacters(in: .whitespaces)
    }
    
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        inputNode = audioEngine.inputNode
    }
    
    private func requestMicrophonePermission() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            if granted {
                print("Microphone permission granted")
            } else {
                print("Microphone permission denied")
                DispatchQueue.main.async {
                    self.showPermissionAlert()
                }
            }
        }
    }
    
    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Microphone Permission Required"
        alert.informativeText = "Please grant microphone access in System Settings > Privacy & Security > Microphone"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    func toggleRecording() {
        isRecording.toggle()
        
        if isRecording {
            startRecording()
        } else {
            stopRecording()
        }
    }
    
    func startRecording() {
        audioBuffer.removeAll()
        
        // Set up global Escape key monitor to cancel recording
        escapeKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // 53 is the key code for Escape
                if self?.isRecording == true {
                    print("🛑 Recording cancelled by Escape key")
                    DispatchQueue.main.async {
                        self?.cancelRecording()
                    }
                }
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            
            let channelData = buffer.floatChannelData?[0]
            let frameLength = Int(buffer.frameLength)
            let inputSampleRate = buffer.format.sampleRate
            
            if let channelData = channelData {
                // Collect raw samples
                let samples = Array(UnsafeBufferPointer(start: channelData, count: frameLength))
                
                // Resample to 16kHz if needed for WhisperKit
                if inputSampleRate != self.sampleRate {
                    let ratio = Int(inputSampleRate / self.sampleRate)
                    let resampledSamples = stride(from: 0, to: samples.count, by: ratio).map { samples[$0] }
                    self.audioBuffer.append(contentsOf: resampledSamples)
                } else {
                    self.audioBuffer.append(contentsOf: samples)
                }
                
                // Calculate audio level
                let rms = sqrt(channelData.withMemoryRebound(to: Float.self, capacity: frameLength) { ptr in
                    var sum: Float = 0
                    for i in 0..<frameLength {
                        sum += ptr[i] * ptr[i]
                    }
                    return sum / Float(frameLength)
                })
                
                let db = 20 * log10(max(rms, 0.00001))
                
                DispatchQueue.main.async {
                    self.delegate?.audioLevelDidUpdate(db: db)
                }
            }
        }
        
        do {
            try audioEngine.start()
            print("🎤 Recording started...")
        } catch {
            print("Failed to start audio engine: \(error)")
            isRecording = false
        }
    }
    
    func stopRecording() {
        audioEngine.stop()
        inputNode.removeTap(onBus: 0)
        
        // Remove Escape key monitor
        if let monitor = escapeKeyMonitor {
            NSEvent.removeMonitor(monitor)
            escapeKeyMonitor = nil
        }
        
        print("⏹ Recording stopped")
        print("Captured \(audioBuffer.count) audio samples")
        
        // Process the recording
        Task {
            await processRecording()
        }
    }
    
    func cancelRecording() {
        isRecording = false
        audioEngine.stop()
        inputNode.removeTap(onBus: 0)
        audioBuffer.removeAll()
        
        // Remove Escape key monitor
        if let monitor = escapeKeyMonitor {
            NSEvent.removeMonitor(monitor)
            escapeKeyMonitor = nil
        }
        
        print("Recording cancelled")
        
        delegate?.recordingWasCancelled()
    }
    
    @MainActor
    private func processRecording() async {
        guard !audioBuffer.isEmpty else {
            print("No audio recorded")
            return
        }
        
        // Calculate RMS (Root Mean Square) to detect silence
        let rms = sqrt(audioBuffer.reduce(0) { $0 + $1 * $1 } / Float(audioBuffer.count))
        let db = 20 * log10(max(rms, 0.00001))
        
        // Threshold for silence detection (conservative: -50dB to avoid false positives)
        let silenceThreshold: Float = -50.0
        
        if db < silenceThreshold {
            print("Audio too quiet (RMS: \(rms), dB: \(db)). Skipping transcription.")
            return
        }
        
        // Start transcription
        delegate?.transcriptionDidStart()
        isTranscribing = true
        
        // Load model if not already loaded
        if ModelStateManager.shared.loadedWhisperKit == nil {
            if let selectedModel = ModelStateManager.shared.selectedModel {
                _ = await ModelStateManager.shared.loadModel(selectedModel)
            }
        }
        
        guard let whisperKit = ModelStateManager.shared.loadedWhisperKit else {
            print("WhisperKit not initialized - please select and download a model in Settings")
            isTranscribing = false
            delegate?.transcriptionDidFail(error: "No model loaded. Please select a model in Settings.")
            return
        }
        
        // Check for custom vocabulary support
        let selectedModelName = ModelStateManager.shared.selectedModel ?? ""
        let vocabulary = loadVocabulary()
        
        // Get the actual WhisperKit model name for compatibility checking
        let whisperKitModelName: String
        if let modelInfo = ModelData.availableModels.first(where: { $0.name == selectedModelName }) {
            whisperKitModelName = modelInfo.whisperKitModelName
        } else {
            whisperKitModelName = selectedModelName // fallback
        }
        
        let supportsVocabulary = isVocabularyCompatible(whisperKitModelName)
        let vocabularyToUse = (supportsVocabulary && vocabulary != nil) ? vocabulary : nil
        
        if let vocab = vocabularyToUse {
            print("🎯 Using custom vocabulary: '\(vocab)' for model: \(selectedModelName) (\(whisperKitModelName))")
        } else if vocabulary != nil && !supportsVocabulary {
            print("💡 Custom vocabulary available but not compatible with model: \(selectedModelName) (\(whisperKitModelName))")
        } else {
            print("📝 Using standard transcription (no custom vocabulary)")
        }
        
        print("Transcribing \(audioBuffer.count) samples (\(Double(audioBuffer.count) / sampleRate) seconds)...")
        
        do {
            // Prepare decoding options with optional vocabulary
            var decodingOptions = DecodingOptions(
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
                clipTimestamps: [0],
                suppressBlank: true,
                supressTokens: nil
            )
            
            // Add vocabulary prefix tokens if available and compatible
            if let vocab = vocabularyToUse, let tokenizer = whisperKit.tokenizer {
                let prefixTokens = tokenizer.encode(text: " \(vocab)").filter { 
                    $0 < tokenizer.specialTokens.specialTokenBegin 
                }
                decodingOptions.prefixTokens = prefixTokens
                print("🔤 Added \(prefixTokens.count) vocabulary prefix tokens")
            }
            
            let transcriptionResult = try await whisperKit.transcribe(
                audioArray: audioBuffer,
                decodeOptions: decodingOptions
            )
            
            isTranscribing = false
            
            if let firstResult = transcriptionResult.first {
                var transcription = firstResult.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                
                // Clean vocabulary prefix if it was used
                if let vocab = vocabularyToUse, !transcription.isEmpty {
                    let cleanedTranscription = cleanVocabularyPrefix(transcription, vocabulary: vocab)
                    if cleanedTranscription != transcription {
                        print("🧹 Cleaned vocabulary prefix. Original: '\(transcription)' -> Clean: '\(cleanedTranscription)'")
                        transcription = cleanedTranscription
                    }
                }
                
                if !transcription.isEmpty {
                    print("✅ Transcription: \"\(transcription)\"")
                    
                    // Save to history
                    TranscriptionHistory.shared.addEntry(transcription)
                    
                    // Notify delegate
                    delegate?.transcriptionDidComplete(text: transcription)
                } else {
                    print("No transcription generated (possibly silence)")
                }
            }
        } catch {
            print("Transcription error: \(error)")
            isTranscribing = false
            delegate?.transcriptionDidFail(error: "Transcription failed: \(error.localizedDescription)")
        }
    }
}
