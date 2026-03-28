import Foundation
import os.log

private let audioCollectorLog = Logger(subsystem: "com.supervoiceassistant", category: "AudioCollector")

@available(macOS 14.0, *)
public class GeminiAudioCollector {
    private let apiKey: String
    // Reuse a single WebSocket session to avoid per-sentence handshake overhead
    private var webSocketTask: URLSessionWebSocketTask?
    private var didSendSetup: Bool = false
    private let session = URLSession.shared
    
    public init(apiKey: String) {
        self.apiKey = apiKey
    }

    deinit {
        closeConnection()
    }

    /// Explicitly close the WebSocket connection to free resources
    public func closeConnection() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        didSendSetup = false
    }
    
    public func collectAudioChunks(from text: String, onComplete: ((Result<Void, Error>) -> Void)? = nil) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try await self.performCollection(text: text, continuation: continuation, onComplete: onComplete)
                } catch {
                    // Notify completion with failure and finish the stream
                    onComplete?(.failure(error))
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    private func performCollection(text: String, continuation: AsyncThrowingStream<Data, Error>.Continuation, onComplete: ((Result<Void, Error>) -> Void)? = nil) async throws {
        guard let url = URL(string: "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=\(apiKey)") else {
            throw GeminiAudioCollectorError.invalidURL
        }
        
        // Always create a fresh connection to avoid stale socket issues
        // (Gemini WebSocket connections timeout after ~10 minutes of idle)
        closeConnection()
        let task = session.webSocketTask(with: url)
        task.resume()
        webSocketTask = task

        guard let webSocketTask else {
            throw GeminiAudioCollectorError.invalidURL
        }
        
        do {
            // Send setup message only once per socket
            if !didSendSetup {
                let setupMessage = """
                {
                    "setup": {
                        "model": "models/gemini-2.5-flash-native-audio-preview-12-2025",
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
                didSendSetup = true
            }
            
            // Send text for TTS for this turn
            let textMessage = """
            {
                "client_content": {
                    "turns": [
                        {
                            "role": "user",
                            "parts": [
                                {
                                    "text": "You must only speak the exact text provided. Do not add any introduction, explanation, commentary, or conclusion. Do not ask questions. Do not say anything before or after the text. Only speak these exact words: \(text)"
                                }
                            ]
                        }
                    ],
                    "turn_complete": true
                }
            }
            """
            try await webSocketTask.send(.string(textMessage))
            
            // Collect audio chunks and yield them immediately for this turn
            var isComplete = false
            while !isComplete {
                let message = try await webSocketTask.receive()
                
                switch message {
                case .string(let text):
                    // Log full response for debugging
                    print("📝 Received text message: \(text)")

                    // Check for error responses
                    if let data = text.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let error = json["error"] as? [String: Any] {
                            let code = error["code"] as? Int ?? -1
                            let message = error["message"] as? String ?? "Unknown error"
                            let status = error["status"] as? String ?? ""
                            print("🚨 API Error - Code: \(code), Status: \(status), Message: \(message)")
                            audioCollectorLog.error("API Error - Code: \(code), Status: \(status, privacy: .public), Message: \(message, privacy: .public)")
                        }
                    }

                    if text.contains("\"done\":true") || text.contains("turn_complete") || text.contains("\"turnComplete\":true") {
                        isComplete = true
                    }
                case .data(let data):
                    do {
                        if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] {

                            // Check for API errors in data response
                            if let error = jsonObject["error"] as? [String: Any] {
                                let code = error["code"] as? Int ?? -1
                                let message = error["message"] as? String ?? "Unknown error"
                                let status = error["status"] as? String ?? ""
                                print("🚨 API Error - Code: \(code), Status: \(status), Message: \(message)")
                                audioCollectorLog.error("API Error (data) - Code: \(code), Status: \(status, privacy: .public), Message: \(message, privacy: .public)")
                            }

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
                        audioCollectorLog.warning("JSON parsing error: \(error.localizedDescription, privacy: .public)")
                    }
                @unknown default:
                    break
                }
            }
            
            print("✅ Audio collection complete")
            // Notify successful completion before finishing the stream
            onComplete?(.success(()))
            continuation.finish()
            
        } catch {
            // Close connection on error to prevent resource leaks
            audioCollectorLog.error("Audio collection failed: \(error.localizedDescription, privacy: .public)")
            closeConnection()
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
