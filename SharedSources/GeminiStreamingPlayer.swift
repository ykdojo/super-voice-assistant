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
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        playerNode.stop()
    }
    
    public func playAudioStream(_ audioStream: AsyncThrowingStream<Data, Error>) async throws {
        try startAudioEngine()
        
        var isFirstChunk = true
        var totalBytesPlayed = 0
        
        do {
            for try await audioChunk in audioStream {
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