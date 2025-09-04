import Foundation

@available(macOS 14.0, *)
public class GeminiAudioCollector {
    private let apiKey: String
    
    public init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    public func collectAudioChunks(from text: String) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try await self.performCollection(text: text, continuation: continuation)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    private func performCollection(text: String, continuation: AsyncThrowingStream<Data, Error>.Continuation) async throws {
        guard let url = URL(string: "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent?key=\(apiKey)") else {
            throw GeminiAudioCollectorError.invalidURL
        }
        
        let session = URLSession.shared
        let webSocketTask = session.webSocketTask(with: url)
        webSocketTask.resume()
        
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
                                    "text": "You must only speak the exact text provided. Do not add any introduction, explanation, commentary, or conclusion. Do not ask questions. Do not say anything before or after the text. When speaking multiple sentences, pause naturally between sentences for better clarity. Only speak these exact words: \(text)"
                                }
                            ]
                        }
                    ],
                    "turn_complete": true
                }
            }
            """
            
            try await webSocketTask.send(.string(textMessage))
            
            // Collect audio chunks and yield them immediately
            var isComplete = false
            
            while !isComplete {
                let message = try await webSocketTask.receive()
                
                switch message {
                case .string(let text):
                    print("📝 Received text message: \(text)")
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
                            }
                            
                            // Extract audio data and yield immediately
                            if let serverContent = jsonObject["serverContent"] as? [String: Any],
                               let modelTurn = serverContent["modelTurn"] as? [String: Any],
                               let parts = modelTurn["parts"] as? [[String: Any]] {
                                
                                for part in parts {
                                    if let inlineData = part["inlineData"] as? [String: Any],
                                       let mimeType = inlineData["mimeType"] as? String,
                                       mimeType.starts(with: "audio/pcm"),
                                       let base64Data = inlineData["data"] as? String,
                                       let actualAudioData = Data(base64Encoded: base64Data) {
                                        
                                        print("🎵 Yielding audio chunk: \(actualAudioData.count) bytes")
                                        continuation.yield(actualAudioData)
                                    }
                                }
                            }
                        }
                    } catch {
                        print("⚠️ JSON parsing error: \(error)")
                    }
                @unknown default:
                    break
                }
                
                try await Task.sleep(nanoseconds: 10_000_000) // 10ms polling
            }
            
            print("✅ Audio collection complete")
            continuation.finish()
            
        } catch {
            throw GeminiAudioCollectorError.collectionError(error)
        }
    }
}

public enum GeminiAudioCollectorError: Error, LocalizedError {
    case invalidURL
    case collectionError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid WebSocket URL"
        case .collectionError(let error):
            return "Audio collection error: \(error.localizedDescription)"
        }
    }
}