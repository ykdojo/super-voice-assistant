import Foundation
import AVFoundation

@available(macOS 14.0, *)
public class GeminiTTS {
    private let apiKey: String
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let timePitchEffect = AVAudioUnitTimePitch()
    private let audioFormat: AVAudioFormat
    
    public init(apiKey: String, playbackSpeed: Float = 1.15) {
        self.apiKey = apiKey
        self.audioFormat = AVAudioFormat(standardFormatWithSampleRate: 24000, channels: 1)!
        
        // Setup audio processing chain
        timePitchEffect.rate = playbackSpeed
        timePitchEffect.pitch = 0 // Keep pitch unchanged
        
        audioEngine.attach(playerNode)
        audioEngine.attach(timePitchEffect)
        audioEngine.connect(playerNode, to: timePitchEffect, format: audioFormat)
        audioEngine.connect(timePitchEffect, to: audioEngine.mainMixerNode, format: audioFormat)
    }
    
    public func startAudioEngine() throws {
        if !audioEngine.isRunning {
            try audioEngine.start()
        }
    }
    
    public func stopAudioEngine() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
    }
    
    public func synthesizeSpeech(_ text: String) async throws {
        guard let url = URL(string: "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent?key=\(apiKey)") else {
            throw GeminiTTSError.invalidURL
        }
        
        let session = URLSession.shared
        let webSocketTask = session.webSocketTask(with: url)
        webSocketTask.resume()
        
        try startAudioEngine()
        
        defer {
            webSocketTask.cancel(with: .goingAway, reason: nil)
        }
        
        do {
            // Send setup message
            let setupMessage = """
            {
                "setup": {
                    "model": "models/gemini-2.0-flash-live-001",
                    "generation_config": {
                        "response_modalities": ["AUDIO"],
                        "speech_config": {
                            "voice_config": {
                                "prebuilt_voice_config": {
                                    "voice_name": "Aoede"
                                }
                            }
                        }
                    }
                }
            }
            """
            
            try await webSocketTask.send(.string(setupMessage))
            
            // Wait for setup confirmation
            _ = try await webSocketTask.receive()
            
            // Send text for TTS
            let textMessage = """
            {
                "client_content": {
                    "turns": [
                        {
                            "role": "user",
                            "parts": [
                                {
                                    "text": "Read out loud the following text with nothing before or after: \(text)"
                                }
                            ]
                        }
                    ],
                    "turn_complete": true
                }
            }
            """
            
            try await webSocketTask.send(.string(textMessage))
            
            // Collect and play audio
            let audioData = try await collectAudioData(from: webSocketTask)
            try await playAudioData(audioData)
            
        } catch {
            throw GeminiTTSError.synthesisError(error)
        }
    }
    
    private func collectAudioData(from webSocketTask: URLSessionWebSocketTask) async throws -> Data {
        var audioData = Data()
        var isComplete = false
        
        while !isComplete {
            let message = try await webSocketTask.receive()
            
            switch message {
            case .string(let text):
                if text.contains("\"done\":true") || text.contains("turn_complete") || text.contains("\"turnComplete\":true") {
                    isComplete = true
                }
            case .data(let data):
                do {
                    if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        
                        // Check for completion in JSON response
                        if let serverContent = jsonObject["serverContent"] as? [String: Any],
                           let turnComplete = serverContent["turnComplete"] as? Bool,
                           turnComplete {
                            isComplete = true
                            break
                        }
                        
                        // Extract audio data
                        if let serverContent = jsonObject["serverContent"] as? [String: Any],
                           let modelTurn = serverContent["modelTurn"] as? [String: Any],
                           let parts = modelTurn["parts"] as? [[String: Any]] {
                            
                            for part in parts {
                                if let inlineData = part["inlineData"] as? [String: Any],
                                   let mimeType = inlineData["mimeType"] as? String,
                                   mimeType.starts(with: "audio/pcm"),
                                   let base64Data = inlineData["data"] as? String,
                                   let actualAudioData = Data(base64Encoded: base64Data) {
                                    
                                    audioData.append(actualAudioData)
                                }
                            }
                        }
                    }
                } catch { }
            @unknown default:
                break
            }
            
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms polling
        }
        
        return audioData
    }
    
    private func playAudioData(_ audioData: Data) async throws {
        guard !audioData.isEmpty else {
            throw GeminiTTSError.noAudioData
        }
        
        // Create WAV file for playback
        let wavURL = URL(fileURLWithPath: "/tmp/gemini_tts_output.wav")
        let wavData = createWAVData(from: audioData)
        try wavData.write(to: wavURL)
        
        // Play audio through AVAudioEngine
        let audioFile = try AVAudioFile(forReading: wavURL)
        let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: UInt32(audioFile.length))!
        try audioFile.read(into: buffer)
        
        playerNode.scheduleBuffer(buffer, completionHandler: nil)
        playerNode.play()
        
        // Wait for playback completion
        let duration = Double(audioFile.length) / audioFile.fileFormat.sampleRate
        try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
    }
    
    private func createWAVData(from audioData: Data) -> Data {
        var wavData = Data()
        let sampleRate: UInt32 = 24000
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = sampleRate * UInt32(channels * bitsPerSample / 8)
        let blockAlign = channels * bitsPerSample / 8
        let dataSize = UInt32(audioData.count)
        
        // WAV header
        wavData.append("RIFF".data(using: .ascii)!)
        wavData.append(withUnsafeBytes(of: (36 + dataSize).littleEndian) { Data($0) })
        wavData.append("WAVE".data(using: .ascii)!)
        wavData.append("fmt ".data(using: .ascii)!)
        wavData.append(withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: channels.littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: sampleRate.littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: byteRate.littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: blockAlign.littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: bitsPerSample.littleEndian) { Data($0) })
        wavData.append("data".data(using: .ascii)!)
        wavData.append(withUnsafeBytes(of: dataSize.littleEndian) { Data($0) })
        wavData.append(audioData)
        
        return wavData
    }
}

public enum GeminiTTSError: Error, LocalizedError {
    case invalidURL
    case noAudioData
    case synthesisError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid WebSocket URL"
        case .noAudioData:
            return "No audio data received"
        case .synthesisError(let error):
            return "Speech synthesis error: \(error.localizedDescription)"
        }
    }
}