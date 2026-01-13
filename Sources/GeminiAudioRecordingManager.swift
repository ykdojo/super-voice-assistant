import Foundation
import AVFoundation
import AppKit
import SharedModels
import CoreAudio

protocol GeminiAudioRecordingManagerDelegate: AnyObject {
    func audioLevelDidUpdate(db: Float)
    func transcriptionDidStart()
    func transcriptionDidComplete(text: String)
    func transcriptionDidFail(error: String)
    func recordingWasCancelled()
    func recordingWasSkippedDueToSilence()
}

class GeminiAudioRecordingManager {
    weak var delegate: GeminiAudioRecordingManagerDelegate?

    // Audio properties
    private var audioEngine: AVAudioEngine!
    private var inputNode: AVAudioInputNode!
    private var audioBuffer: [Float] = []
    private let sampleRate: Double = 16000

    // Recording state
    var isRecording = false
    private var isStartingRecording = false
    private var escapeKeyMonitor: Any?

    // Gemini transcriber
    private let geminiTranscriber = GeminiAudioTranscriber()

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
                    print("🛑 Gemini recording cancelled by Escape key")
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

                // Resample to 16kHz
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
            audioEngine.prepare()
            try audioEngine.start()
            print("🎤 Gemini audio recording started...")
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

        print("⏹ Gemini recording stopped")
        print("Captured \(audioBuffer.count) audio samples")

        // Process the recording
        processRecording()
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

        print("Gemini recording cancelled")

        delegate?.recordingWasCancelled()
    }

    private func processRecording() {
        guard !audioBuffer.isEmpty else {
            print("No audio recorded")
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

        // Threshold for silence detection
        let silenceThreshold: Float = -55.0

        if db < silenceThreshold {
            print("Audio too quiet (RMS: \(rms), dB: \(db)). Skipping transcription.")
            delegate?.recordingWasSkippedDueToSilence()
            return
        }

        // Start transcription
        delegate?.transcriptionDidStart()

        print("Sending audio to Gemini API for transcription (\(Double(audioBuffer.count) / sampleRate) seconds)...")

        // Send to Gemini API
        geminiTranscriber.transcribe(audioBuffer: audioBuffer) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let transcription):
                    var trimmed = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        // Apply text replacements from config
                        trimmed = TextReplacements.shared.processText(trimmed)

                        print("✅ Gemini transcription: \"\(trimmed)\"")

                        // Save to history
                        TranscriptionHistory.shared.addEntry(trimmed)

                        // Notify delegate
                        self?.delegate?.transcriptionDidComplete(text: trimmed)
                    } else {
                        print("No transcription generated (possibly silence)")
                        self?.delegate?.recordingWasSkippedDueToSilence()
                    }

                case .failure(let error):
                    print("Gemini transcription error: \(error.localizedDescription)")
                    self?.delegate?.transcriptionDidFail(error: "Gemini transcription failed: \(error.localizedDescription)")
                }
            }
        }
    }
}
