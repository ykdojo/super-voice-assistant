import Foundation
import AVFoundation

@available(macOS 14.0, *)
public class GeminiStreamingPlayer {
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let timePitchEffect = AVAudioUnitTimePitch()
    private let audioFormat: AVAudioFormat
    
    public init(playbackSpeed: Float = 1.15) {
        self.audioFormat = AVAudioFormat(standardFormatWithSampleRate: 24000, channels: 1)!
        
        // Setup audio processing chain (same as GeminiTTS)
        timePitchEffect.rate = playbackSpeed
        timePitchEffect.pitch = 0 // Keep pitch unchanged
        
        audioEngine.attach(playerNode)
        audioEngine.attach(timePitchEffect)
        audioEngine.connect(playerNode, to: timePitchEffect, format: audioFormat)
        audioEngine.connect(timePitchEffect, to: audioEngine.mainMixerNode, format: audioFormat)
    }
    
    private func startAudioEngine() throws {
        if !audioEngine.isRunning {
            try audioEngine.start()
        }
    }
    
    public func stopAudioEngine() {
        print("🛑 Stopping audio engine and player")
        playerNode.stop()
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
            
        } catch {
            throw GeminiStreamingPlayerError.playbackError(error)
        }
    }
    
    public func playTextWithSentencePauses(_ text: String, audioCollector: GeminiAudioCollector, pauseDurationMs: Int = 0) async throws {
        try startAudioEngine()
        
        // Split text into sentences
        let sentences = SmartSentenceSplitter.splitIntoSentences(text)
        print("📖 Split text into \(sentences.count) sentences")
        
        if sentences.isEmpty {
            return
        }
        
        var isFirstChunk = true
        
        // Prefetch one sentence ahead to minimize gaps between sentences
        var currentIndex = 0
        print("🚀 Starting collection for sentence 1/\(sentences.count)")
        var currentStream: AsyncThrowingStream<Data, Error> = audioCollector.collectAudioChunks(from: sentences[currentIndex]) { result in
            switch result {
            case .success:
                print("✅ Audio collection complete for sentence \(currentIndex + 1)")
            case .failure(let error):
                print("❌ Audio collection failed for sentence \(currentIndex + 1): \(error)")
            }
        }
        
        // Kick off collection for the next sentence (if any)
        var nextStream: AsyncThrowingStream<Data, Error>? = nil
        if sentences.count > 1 {
            let nextIndex = currentIndex + 1
            print("🧠 Prefetching sentence \(nextIndex + 1)/\(sentences.count)")
            nextStream = audioCollector.collectAudioChunks(from: sentences[nextIndex]) { result in
                switch result {
                case .success:
                    print("✅ Audio collection complete for sentence \(nextIndex + 1)")
                case .failure(let error):
                    print("❌ Audio collection failed for sentence \(nextIndex + 1): \(error)")
                }
            }
        }
        
        while currentIndex < sentences.count {
            print("🔊 Processing sentence \(currentIndex + 1)/\(sentences.count)")
            var sentenceBytesPlayed = 0
            
            // Stream and play this sentence's audio chunks as they arrive
            for try await chunk in currentStream {
                try Task.checkCancellation()
                
                let buffer = try createPCMBuffer(from: chunk)
                
                if isFirstChunk {
                    print("▶️ Starting playback")
                    playerNode.play()
                    isFirstChunk = false
                }
                
                playerNode.scheduleBuffer(buffer, completionHandler: nil)
                sentenceBytesPlayed += chunk.count
                
                // Small pacing to avoid overwhelming scheduling
                try await Task.sleep(nanoseconds: 1_000_000) // 1ms between chunks
            }
            
            print("✅ Sentence \(currentIndex + 1) playback complete: \(sentenceBytesPlayed) bytes")
            
            // Add pause between sentences (except after the last sentence)
            if currentIndex < sentences.count - 1 {
                if pauseDurationMs > 0 {
                    print("⏸️ Adding \(pauseDurationMs)ms pause between sentences")
                    try await addSentencePause(pauseDurationMs: pauseDurationMs)
                } else {
                    print("⏭️ No pause between sentences")
                }
            }
            
            // Advance to next sentence
            currentIndex += 1
            if currentIndex >= sentences.count {
                break
            }
            
            // Swap in prefetched stream if available; otherwise start collection now
            if let prefetched = nextStream {
                currentStream = prefetched
            } else {
                print("🚀 (Fallback) Starting collection for sentence \(currentIndex + 1)/\(sentences.count)")
                currentStream = audioCollector.collectAudioChunks(from: sentences[currentIndex]) { result in
                    switch result {
                    case .success:
                        print("✅ Audio collection complete for sentence \(currentIndex + 1)")
                    case .failure(let error):
                        print("❌ Audio collection failed for sentence \(currentIndex + 1): \(error)")
                    }
                }
            }
            
            // Start prefetch of the following sentence (one-ahead), if any
            let upcomingIndex = currentIndex + 1
            if upcomingIndex < sentences.count {
                print("🧠 Prefetching sentence \(upcomingIndex + 1)/\(sentences.count)")
                nextStream = audioCollector.collectAudioChunks(from: sentences[upcomingIndex]) { result in
                    switch result {
                    case .success:
                        print("✅ Audio collection complete for sentence \(upcomingIndex + 1)")
                    case .failure(let error):
                        print("❌ Audio collection failed for sentence \(upcomingIndex + 1): \(error)")
                    }
                }
            } else {
                nextStream = nil
            }
        }
        
        print("🎉 All sentences completed with prefetch streaming")
    }
    
    private func addSentencePause(pauseDurationMs: Int) async throws {
        guard pauseDurationMs > 0 else { return }
        // Create a silent buffer for the pause
        let sampleRate = audioFormat.sampleRate
        let pauseSamples = Int(sampleRate * Double(pauseDurationMs) / 1000.0)
        
        guard let silenceBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: UInt32(pauseSamples)) else {
            return // Skip pause if we can't create buffer
        }
        
        silenceBuffer.frameLength = UInt32(pauseSamples)
        
        // Clear the buffer to create silence
        if let channelData = silenceBuffer.floatChannelData {
            for channel in 0..<Int(audioFormat.channelCount) {
                memset(channelData[channel], 0, Int(pauseSamples) * MemoryLayout<Float>.size)
            }
        }
        
        // Schedule the silence buffer
        playerNode.scheduleBuffer(silenceBuffer, completionHandler: nil)
        
        // Wait for the pause duration
        try await Task.sleep(nanoseconds: UInt64(pauseDurationMs * 1_000_000))
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
