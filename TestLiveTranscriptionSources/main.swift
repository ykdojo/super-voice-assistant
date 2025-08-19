import Foundation
import AVFoundation
import WhisperKit
import SharedModels

@MainActor
class LiveTranscriptionTest {
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var whisperKit: WhisperKit?
    private var isRecording = false
    private var audioBuffer: [Float] = []
    private let sampleRate: Double = 16000
    
    init() {
        setupAudio()
    }
    
    private func setupAudio() {
        audioEngine = AVAudioEngine()
        inputNode = audioEngine?.inputNode
    }
    
    func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    func loadWhisperModel() async throws {
        let modelName = "openai_whisper-tiny"
        let modelManager = WhisperModelManager.shared
        
        print("Loading WhisperKit with model: \(modelName)")
        
        let modelPath = modelManager.getModelPath(for: modelName)
        if !modelManager.isModelDownloaded(modelName) {
            throw NSError(domain: "TestLiveTranscription", code: 1, 
                         userInfo: [NSLocalizedDescriptionKey: "Model \(modelName) is not downloaded. Please run TestDownload first."])
        }
        
        whisperKit = try await WhisperKit(
            modelFolder: modelPath.path,
            verbose: true,
            logLevel: .debug
        )
        
        print("WhisperKit loaded successfully")
    }
    
    func startRecording() throws {
        guard let audioEngine = audioEngine,
              let inputNode = inputNode,
              !isRecording else {
            print("Already recording or audio engine not set up")
            return
        }
        
        // Use the input node's format for the tap (consistent with main app)
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        audioBuffer.removeAll()
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            
            let channelData = buffer.floatChannelData?[0]
            let frameLength = Int(buffer.frameLength)
            let inputSampleRate = buffer.format.sampleRate
            
            if let channelData = channelData {
                // Collect raw samples first (same as main app)
                let samples = Array(UnsafeBufferPointer(start: channelData, count: frameLength))
                
                // Resample to 16kHz if needed for WhisperKit
                if inputSampleRate != self.sampleRate {
                    let ratio = Int(inputSampleRate / self.sampleRate)
                    let resampledSamples = stride(from: 0, to: samples.count, by: ratio).map { samples[$0] }
                    self.audioBuffer.append(contentsOf: resampledSamples)
                } else {
                    self.audioBuffer.append(contentsOf: samples)
                }
            }
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true
        print("Recording started... Press Enter to stop and transcribe")
    }
    
    func stopRecording() {
        guard let audioEngine = audioEngine, isRecording else {
            print("Not recording")
            return
        }
        
        audioEngine.stop()
        inputNode?.removeTap(onBus: 0)
        isRecording = false
        print("Recording stopped")
    }
    
    func transcribeRecording() async throws -> String? {
        guard let whisperKit = whisperKit else {
            print("WhisperKit not initialized")
            return nil
        }
        
        guard !audioBuffer.isEmpty else {
            print("No audio recorded")
            return nil
        }
        
        // Calculate RMS (Root Mean Square) to detect silence
        let rms = sqrt(audioBuffer.reduce(0) { $0 + $1 * $1 } / Float(audioBuffer.count))
        let db = 20 * log10(max(rms, 0.00001))
        
        // Threshold for silence detection (conservative: -50dB to avoid false positives)
        let silenceThreshold: Float = -50.0
        
        if db < silenceThreshold {
            print("Audio too quiet (RMS: \(rms), dB: \(db)). Skipping transcription.")
            return nil
        }
        
        print("Transcribing \(audioBuffer.count) samples (\(Double(audioBuffer.count) / sampleRate) seconds)...")
        
        let transcriptionResult = try await whisperKit.transcribe(
            audioArray: audioBuffer,
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
                clipTimestamps: [0],
                suppressBlank: true,
                supressTokens: nil
            )
        )
        
        if let firstResult = transcriptionResult.first {
            let transcription = firstResult.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            return transcription.isEmpty ? nil : transcription
        }
        
        return nil
    }
}

@main
struct TestLiveTranscription {
    static func main() async {
        print("Live Transcription Test")
        print("========================")
        
        let test = LiveTranscriptionTest()
        
        print("Requesting microphone permission...")
        let hasPermission = await test.requestMicrophonePermission()
        
        guard hasPermission else {
            print("❌ Microphone permission denied")
            print("Please grant microphone access in System Settings > Privacy & Security > Microphone")
            exit(1)
        }
        
        print("✅ Microphone permission granted")
        
        do {
            print("\nLoading WhisperKit model...")
            try await test.loadWhisperModel()
            print("✅ Model loaded successfully")
            
            print("\nStarting recording...")
            try test.startRecording()
            
            print("\nSpeak into your microphone...")
            print("Press Enter when done speaking to stop and transcribe")
            
            _ = readLine()
            
            test.stopRecording()
            
            print("\nTranscribing audio...")
            if let transcription = try await test.transcribeRecording() {
                print("\n✅ Transcription successful!")
                print("📝 Text: \"\(transcription)\"")
            } else {
                print("❌ No transcription generated (possibly silence or very short audio)")
            }
            
        } catch {
            print("❌ Error: \(error)")
            exit(1)
        }
        
        print("\nTest completed!")
    }
}