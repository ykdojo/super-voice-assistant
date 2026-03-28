import Foundation
import AVFoundation
import os.log

private let streamingPlayerLog = Logger(subsystem: "com.supervoiceassistant", category: "StreamingPlayer")

@available(macOS 14.0, *)
public class GeminiStreamingPlayer {
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let timePitchEffect = AVAudioUnitTimePitch()
    private let audioFormat: AVAudioFormat
    
    public init(playbackSpeed: Float = 1.2) {
        self.audioFormat = AVAudioFormat(standardFormatWithSampleRate: 24000, channels: 1)!

        // Setup audio processing chain (same as GeminiTTS)
        timePitchEffect.rate = playbackSpeed
        timePitchEffect.pitch = 0 // Keep pitch unchanged

        audioEngine.attach(playerNode)
        audioEngine.attach(timePitchEffect)
        audioEngine.connect(playerNode, to: timePitchEffect, format: audioFormat)
        audioEngine.connect(timePitchEffect, to: audioEngine.mainMixerNode, format: audioFormat)

        // Don't configure on init to avoid crashes, will configure when starting engine
    }

    deinit {
        stopAudioEngine()
    }

    /// Reset player state to free scheduled buffers
    public func reset() {
        playerNode.stop()
        playerNode.reset()
    }
    
    private func configureOutputDevice() {
        let deviceManager = AudioDeviceManager.shared
        
        guard !deviceManager.useSystemDefaultOutput,
              let device = deviceManager.getCurrentOutputDevice(),
              let deviceID = deviceManager.getAudioDeviceID(for: device.uid) else {
            return
        }
        
        do {
            try audioEngine.outputNode.auAudioUnit.setDeviceID(deviceID)
            print("✅ Set output device to: \(device.name)")
        } catch {
            print("❌ Failed to set output device: \(error)")
        }
    }
    
    private func startAudioEngine() throws {
        // Reconfigure output device in case settings changed
        configureOutputDevice()
        
        if !audioEngine.isRunning {
            try audioEngine.start()
        }
    }
    
    public func stopAudioEngine() {
        print("🛑 Stopping audio engine and player")
        playerNode.stop()
        playerNode.reset()  // Clear any scheduled buffers to free memory
        if audioEngine.isRunning {
            audioEngine.stop()
        }
    }
    
    public func playAudioStream(_ audioStream: AsyncThrowingStream<Data, Error>) async throws {
        try startAudioEngine()
        
        var isFirstChunk = true
        var totalBytesPlayed = 0
        
        do {
            for try await audioChunk in audioStream {
                // Check for cancellation
                try Task.checkCancellation()
                
                print("🎵 Playing chunk: \(audioChunk.count) bytes")
                
                // Convert raw PCM data to AVAudioPCMBuffer
                let buffer = try createPCMBuffer(from: audioChunk)
                
                if isFirstChunk {
                    print("▶️ Starting playback with first chunk")
                    playerNode.play()
                    isFirstChunk = false
                }
                
                // Schedule buffer for immediate playback
                playerNode.scheduleBuffer(buffer, completionHandler: nil)
                totalBytesPlayed += audioChunk.count
                
                print("📊 Total audio scheduled: \(totalBytesPlayed) bytes")
                
                // Small delay to prevent overwhelming the audio system
                try await Task.sleep(nanoseconds: 1_000_000) // 1ms
            }
            
            print("✅ All audio chunks scheduled for playback")

            // Wait for playback to complete
            let totalDurationSeconds = Double(totalBytesPlayed) / Double(audioFormat.sampleRate * 2) // 16-bit = 2 bytes per sample
            print("⏱️ Waiting \(String(format: "%.1f", totalDurationSeconds))s for playback completion")
            try await Task.sleep(nanoseconds: UInt64(totalDurationSeconds * 1_000_000_000))

            // Clean up after playback
            reset()

        } catch {
            streamingPlayerLog.error("Playback stream error: \(error.localizedDescription, privacy: .public)")
            reset()  // Clean up on error too
            throw GeminiStreamingPlayerError.playbackError(error)
        }
    }
    
    public func playText(_ text: String, audioCollector: GeminiAudioCollector, maxRetries: Int = 3) async throws {
        try startAudioEngine()

        // Split text into sentences and rejoin with line breaks for natural pauses
        let sentences = SmartSentenceSplitter.splitIntoSentences(text)
        print("📖 Split text into \(sentences.count) sentences")

        // Join sentences with triple line breaks to encourage model to add longer pauses
        let formattedText = sentences.joined(separator: "\n\n\n")
        print("📝 Formatted text with line breaks between sentences")

        var lastError: Error?

        for attempt in 1...maxRetries {
            do {
                try await playTextAttempt(formattedText, audioCollector: audioCollector)
                return // Success
            } catch {
                lastError = error

                // Check if it's a network error worth retrying
                let nsError = error as NSError
                let isNetworkError = nsError.domain == NSURLErrorDomain ||
                    (error as? GeminiAudioCollectorError) != nil

                if isNetworkError && attempt < maxRetries {
                    print("⚠️ TTS attempt \(attempt) failed, retrying in 1s... Error: \(error.localizedDescription)")
                    streamingPlayerLog.warning("TTS attempt \(attempt) failed, retrying: \(error.localizedDescription, privacy: .public)")
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                    reset() // Reset player state before retry
                } else {
                    throw error
                }
            }
        }

        // Should not reach here, but just in case
        if let error = lastError {
            throw error
        }
    }

    private func playTextAttempt(_ formattedText: String, audioCollector: GeminiAudioCollector) async throws {
        var isFirstChunk = true
        var totalBytesPlayed = 0

        // Start collection for the formatted text (all at once)
        let audioStream = audioCollector.collectAudioChunks(from: formattedText) { result in
            switch result {
            case .success:
                print("✅ Audio collection complete")
            case .failure(let error):
                print("❌ Audio collection failed: \(error)")
            }
        }

        // Stream and play audio chunks as they arrive
        for try await chunk in audioStream {
            try Task.checkCancellation()

            let buffer = try createPCMBuffer(from: chunk)

            if isFirstChunk {
                print("▶️ Starting playback")
                playerNode.play()
                isFirstChunk = false
            }

            playerNode.scheduleBuffer(buffer, completionHandler: nil)
            totalBytesPlayed += chunk.count

            // Small pacing to avoid overwhelming scheduling
            try await Task.sleep(nanoseconds: 1_000_000) // 1ms between chunks
        }

        print("✅ Playback complete: \(totalBytesPlayed) bytes")
        print("🎉 Full text streaming completed")

        // Clean up after playback
        reset()
    }
    
    private func createPCMBuffer(from audioData: Data) throws -> AVAudioPCMBuffer {
        let frameCount = audioData.count / 2 // 16-bit samples = 2 bytes per frame
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: UInt32(frameCount)) else {
            throw GeminiStreamingPlayerError.bufferCreationFailed
        }
        
        buffer.frameLength = UInt32(frameCount)
        
        // Copy audio data into buffer
        audioData.withUnsafeBytes { bytes in
            let int16Pointer = bytes.bindMemory(to: Int16.self)
            let floatPointer = buffer.floatChannelData![0]
            
            // Convert Int16 samples to Float samples (normalized to -1.0 to 1.0)
            for i in 0..<frameCount {
                floatPointer[i] = Float(int16Pointer[i]) / Float(Int16.max)
            }
        }
        
        return buffer
    }
}

public enum GeminiStreamingPlayerError: Error, LocalizedError {
    case bufferCreationFailed
    case playbackError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .bufferCreationFailed:
            return "Failed to create audio buffer"
        case .playbackError(let error):
            return "Playback error: \(error.localizedDescription)"
        }
    }
}
