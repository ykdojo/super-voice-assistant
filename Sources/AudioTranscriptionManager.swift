import Foundation
import AVFoundation
import WhisperKit
import AppKit
import SharedModels
import CoreAudio

protocol AudioTranscriptionManagerDelegate: AnyObject {
    func audioLevelDidUpdate(db: Float)
    func transcriptionDidStart()
    func transcriptionDidComplete(text: String)
    func transcriptionDidFail(error: String)
    func recordingWasCancelled()
    func recordingWasSkippedDueToSilence()
}

class AudioTranscriptionManager {
    weak var delegate: AudioTranscriptionManagerDelegate?
    
    // Audio properties
    private var audioEngine: AVAudioEngine!
    private var inputNode: AVAudioInputNode!
    private var audioBuffer: [Float] = []
    private let sampleRate: Double = 16000
    private let maxBufferSamples = 16000 * 300  // 5 minutes max to prevent memory explosion
    
    // Recording state
    var isRecording = false
    private var isStartingRecording = false  // Prevents race condition
    private var escapeKeyMonitor: Any?
    
    // Transcription state
    private var isTranscribing = false
    
    init() {
        setupAudioEngine()
        requestMicrophonePermission()
    }
    
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        inputNode = audioEngine.inputNode
        configureInputDevice()
    }
    
    private func configureInputDevice() {
        let deviceManager = AudioDeviceManager.shared

        // Check if user selected a specific device - set it as system default temporarily
        if !deviceManager.useSystemDefaultInput,
           let selectedUID = deviceManager.selectedInputDeviceUID,
           let deviceID = deviceManager.getAudioDeviceID(for: selectedUID) {

            // Set as system default input device
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultInputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )

            var deviceIDValue = deviceID
            let status = AudioObjectSetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &propertyAddress,
                0,
                nil,
                UInt32(MemoryLayout<AudioDeviceID>.size),
                &deviceIDValue
            )

            if status == noErr {
                let deviceName = deviceManager.availableInputDevices.first { $0.uid == selectedUID }?.name ?? selectedUID
                print("✅ Set system default input to: \(deviceName)")
            } else {
                print("⚠️ Failed to set default input device (error: \(status))")
            }
        } else {
            print("✅ Using system default input device")
        }

        let format = inputNode.outputFormat(forBus: 0)
        print("   Format: \(format.sampleRate)Hz, \(format.channelCount) channels")
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
        // Prevent race condition if called while starting
        if isStartingRecording {
            return
        }

        isRecording.toggle()

        if isRecording {
            startRecording()
        } else {
            stopRecording()
        }
    }

    func startRecording() {
        isStartingRecording = true
        audioBuffer.removeAll()

        // Create fresh audio engine to avoid state issues
        audioEngine = AVAudioEngine()
        inputNode = audioEngine.inputNode
        configureInputDevice()

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
        audioEngine.prepare()
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

                // Prevent memory explosion from runaway recording
                if self.audioBuffer.count > self.maxBufferSamples {
                    print("⚠️ Audio buffer limit reached (5 min). Auto-stopping recording.")
                    DispatchQueue.main.async {
                        self.isRecording = false
                        self.stopRecording()
                    }
                    return
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
            isStartingRecording = false
        } catch {
            print("Failed to start audio engine: \(error)")
            isRecording = false
            isStartingRecording = false
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
            // Nothing to transcribe; ensure UI resets
            delegate?.recordingWasSkippedDueToSilence()
            return
        }

        // Skip extremely short recordings to avoid spurious transcriptions
        let durationSeconds = Double(audioBuffer.count) / sampleRate
        let minDurationSeconds: Double = 0.30
        if durationSeconds < minDurationSeconds {
            print("Recording too short (\(String(format: "%.2f", durationSeconds))s). Skipping transcription.")
            delegate?.recordingWasSkippedDueToSilence()
            return
        }

        // Calculate RMS (Root Mean Square) to detect silence
        let rms = sqrt(audioBuffer.reduce(0) { $0 + $1 * $1 } / Float(audioBuffer.count))
        let db = 20 * log10(max(rms, 0.00001))

        // Threshold for silence detection (stricter to avoid false positives)
        // Lowered to -55dB to capture quieter audio
        let silenceThreshold: Float = -55.0

        if db < silenceThreshold {
            print("Audio too quiet (RMS: \(rms), dB: \(db)). Skipping transcription.")
            // Reset the status bar icon when skipping quiet audio
            delegate?.recordingWasSkippedDueToSilence()
            return
        }

        // Start transcription
        delegate?.transcriptionDidStart()
        isTranscribing = true

        // Route to appropriate transcriber based on selected engine
        switch ModelStateManager.shared.selectedEngine {
        case .whisperKit:
            await transcribeWithWhisperKit()
        case .parakeet:
            await transcribeWithParakeet()
        }
    }

    @MainActor
    private func transcribeWithWhisperKit() async {
        // Load model if not already loaded
        if ModelStateManager.shared.loadedWhisperKit == nil {
            if let selectedModel = ModelStateManager.shared.selectedModel {
                _ = await ModelStateManager.shared.loadModel(selectedModel)
            }
        }

        guard let whisperKit = ModelStateManager.shared.loadedWhisperKit else {
            print("WhisperKit not initialized - please select and download a model in Settings")
            isTranscribing = false
            delegate?.transcriptionDidFail(error: "No WhisperKit model loaded. Please select a model in Settings.")
            return
        }

        // Pad short audio with 1 second of silence to improve transcription reliability
        let paddingThresholdSeconds = 1.5
        let paddingDurationSeconds = 1.0
        let minSamplesForPadding = Int(paddingThresholdSeconds * sampleRate)
        let paddingSamples = Int(paddingDurationSeconds * sampleRate)

        var paddedBuffer = audioBuffer
        if audioBuffer.count < minSamplesForPadding {
            paddedBuffer.append(contentsOf: [Float](repeating: 0.0, count: paddingSamples))
            print("Padded short audio with \(paddingDurationSeconds)s of silence")
        }

        print("Transcribing \(audioBuffer.count) samples (\(Double(audioBuffer.count) / sampleRate) seconds) with WhisperKit...")

        do {
            let transcriptionResult = try await whisperKit.transcribe(
                audioArray: paddedBuffer,
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
                    withoutTimestamps: true,
                    clipTimestamps: [],
                    suppressBlank: true,
                    supressTokens: nil
                )
            )

            isTranscribing = false

            if let firstResult = transcriptionResult.first {
                var transcription = firstResult.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                handleTranscriptionResult(transcription)
            }
        } catch {
            print("WhisperKit transcription error: \(error)")
            isTranscribing = false
            delegate?.transcriptionDidFail(error: "Transcription failed: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func transcribeWithParakeet() async {
        // Load model if not already loaded
        if ModelStateManager.shared.loadedParakeetTranscriber == nil ||
           ModelStateManager.shared.parakeetLoadingState != .loaded {
            await ModelStateManager.shared.loadParakeetModel()
        }

        guard let transcriber = ModelStateManager.shared.loadedParakeetTranscriber,
              transcriber.isReady else {
            print("Parakeet not initialized - please select Parakeet in Settings and wait for model to load")
            isTranscribing = false
            delegate?.transcriptionDidFail(error: "No Parakeet model loaded. Please wait for model to download in Settings.")
            return
        }

        // Pad short audio with 1 second of silence to improve transcription reliability
        let paddingThresholdSeconds = 1.5
        let paddingDurationSeconds = 1.0
        let minSamplesForPadding = Int(paddingThresholdSeconds * sampleRate)
        let paddingSamples = Int(paddingDurationSeconds * sampleRate)

        var paddedBuffer = audioBuffer
        if audioBuffer.count < minSamplesForPadding {
            paddedBuffer.append(contentsOf: [Float](repeating: 0.0, count: paddingSamples))
            print("Padded short audio with \(paddingDurationSeconds)s of silence")
        }

        print("Transcribing \(audioBuffer.count) samples (\(Double(audioBuffer.count) / sampleRate) seconds) with Parakeet...")

        do {
            let transcription = try await transcriber.transcribe(audioSamples: paddedBuffer)
            isTranscribing = false
            handleTranscriptionResult(transcription)
        } catch {
            print("Parakeet transcription error: \(error)")
            isTranscribing = false
            delegate?.transcriptionDidFail(error: "Transcription failed: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func handleTranscriptionResult(_ rawTranscription: String) {
        var transcription = rawTranscription.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if !transcription.isEmpty {
            // Apply text replacements from config
            transcription = TextReplacements.shared.processText(transcription)

            print("Transcription: \"\(transcription)\"")

            // Save to history
            TranscriptionHistory.shared.addEntry(transcription)

            // Notify delegate
            delegate?.transcriptionDidComplete(text: transcription)
        } else {
            print("No transcription generated (possibly silence)")
            // Reset UI and avoid leaving the processing indicator running
            delegate?.recordingWasSkippedDueToSilence()
        }
    }
}
