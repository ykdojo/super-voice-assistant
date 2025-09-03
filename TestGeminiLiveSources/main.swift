import Foundation
import AVFoundation

@main
struct GeminiLiveTest {
    static func loadApiKey() -> String? {
        if let envKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] {
            return envKey
        }
        
        let envPath = ".env"
        guard let envContent = try? String(contentsOfFile: envPath, encoding: .utf8) else {
            return nil
        }
        
        for line in envContent.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("GEMINI_API_KEY=") {
                let key = String(trimmed.dropFirst("GEMINI_API_KEY=".count))
                return key.isEmpty ? nil : key
            }
        }
        
        return nil
    }
    
    static func main() async {
        guard let apiKey = loadApiKey() else {
            print("❌ GEMINI_API_KEY not found")
            print("💡 Set environment variable or create .env file")
            exit(1)
        }
        
        print("🚀 Starting Gemini Live API test...")
        print("🔑 API Key loaded successfully")
        
        guard let url = URL(string: "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent?key=\(apiKey)") else {
            print("❌ Invalid WebSocket URL")
            exit(1)
        }
        
        let session = URLSession.shared
        let webSocketTask = session.webSocketTask(with: url)
        webSocketTask.resume()
        
        // Setup audio engine
        let audioEngine = AVAudioEngine()
        let playerNode = AVAudioPlayerNode()
        let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 24000, channels: 1)!
        
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: audioFormat)
        
        do {
            try audioEngine.start()
        } catch {
            print("❌ Failed to start audio engine: \(error)")
            exit(1)
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
            print("📤 Setup message sent")
            
            // Wait for setup response
            let setupResponse = try await webSocketTask.receive()
            print("📥 Setup confirmed")
            
            // Send text for TTS
            let textMessage = """
            {
                "client_content": {
                    "turns": [
                        {
                            "role": "user",
                            "parts": [
                                {
                                    "text": "Hello! This is a test of Gemini's text-to-speech capability."
                                }
                            ]
                        }
                    ],
                    "turn_complete": true
                }
            }
            """
            
            try await webSocketTask.send(.string(textMessage))
            print("📤 Text sent for speech synthesis")
            
            // Collect audio data
            var audioData = Data()
            var responseCount = 0
            let maxResponses = 10
            
            while responseCount < maxResponses {
                let message = try await webSocketTask.receive()
                responseCount += 1
                
                switch message {
                case .string(let text):
                    if text.contains("\"done\":true") || text.contains("turn_complete") {
                        break
                    }
                case .data(let data):
                    // Parse JSON to extract base64 audio
                    do {
                        if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let serverContent = jsonObject["serverContent"] as? [String: Any],
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
                    } catch { }
                @unknown default:
                    break
                }
                
                try await Task.sleep(nanoseconds: 50_000_000)
            }
            
            if !audioData.isEmpty {
                print("🎵 Audio received: \(audioData.count) bytes")
                
                // Create WAV file for playback
                let wavURL = URL(fileURLWithPath: "/tmp/gemini_test_output.wav")
                
                // WAV header for 24kHz, 16-bit, mono
                var wavData = Data()
                let sampleRate: UInt32 = 24000
                let channels: UInt16 = 1
                let bitsPerSample: UInt16 = 16
                let byteRate = sampleRate * UInt32(channels * bitsPerSample / 8)
                let blockAlign = channels * bitsPerSample / 8
                let dataSize = UInt32(audioData.count)
                
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
                
                try? wavData.write(to: wavURL)
                
                // Play audio
                let audioFile = try AVAudioFile(forReading: wavURL)
                let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: UInt32(audioFile.length))!
                try audioFile.read(into: buffer)
                
                print("🔊 Playing audio...")
                playerNode.scheduleBuffer(buffer, completionHandler: nil)
                playerNode.play()
                
                let duration = Double(audioFile.length) / audioFile.fileFormat.sampleRate
                try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                
                print("✅ Text-to-speech test successful!")
            } else {
                print("⚠️ No audio data received")
            }
            
        } catch {
            print("❌ Error: \(error)")
            exit(1)
        }
        
        webSocketTask.cancel(with: .goingAway, reason: nil)
        print("🔌 Connection closed")
    }
}