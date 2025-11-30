import Foundation
import AVFoundation

/// Transcribes audio using Gemini API
public class GeminiAudioTranscriber {

    public init() {}

    public enum TranscriptionError: Error, LocalizedError {
        case apiKeyNotFound
        case audioConversionFailed
        case requestFailed(statusCode: Int, message: String)
        case noTranscriptionInResponse
        case blocked(reason: String)

        public var errorDescription: String? {
            switch self {
            case .apiKeyNotFound:
                return "GEMINI_API_KEY not found in environment or .env file"
            case .audioConversionFailed:
                return "Failed to convert audio to WAV format"
            case .requestFailed(let statusCode, let message):
                return "API request failed (status \(statusCode)): \(message)"
            case .noTranscriptionInResponse:
                return "No transcription text in API response"
            case .blocked(let reason):
                return "Request blocked: \(reason)"
            }
        }
    }

    private struct GenerateContentResponse: Codable {
        let candidates: [Candidate]?
        let promptFeedback: PromptFeedback?

        struct Candidate: Codable {
            let content: Content?
            let finishReason: String?
        }

        struct Content: Codable {
            let parts: [Part]?
        }

        struct Part: Codable {
            let text: String?
        }

        struct PromptFeedback: Codable {
            let blockReason: String?
        }
    }

    /// Transcribe audio buffer using Gemini API
    /// - Parameters:
    ///   - audioBuffer: Float array of audio samples at 16kHz
    ///   - completion: Completion handler with transcription result
    public func transcribe(audioBuffer: [Float], completion: @escaping (Result<String, Error>) -> Void) {
        // Load API key
        guard let apiKey = loadApiKey() else {
            completion(.failure(TranscriptionError.apiKeyNotFound))
            return
        }

        // Pad short audio with 1 second of silence to improve transcription reliability
        let sampleRate = 16000
        let minDurationSeconds: Float = 1.5
        let paddingDurationSeconds: Float = 1.0
        let minSamples = Int(minDurationSeconds * Float(sampleRate))
        let paddingSamples = Int(paddingDurationSeconds * Float(sampleRate))

        var paddedBuffer = audioBuffer
        if audioBuffer.count < minSamples {
            paddedBuffer.append(contentsOf: [Float](repeating: 0.0, count: paddingSamples))
        }

        // Convert audio buffer to WAV data
        guard let wavData = convertToWAV(audioBuffer: paddedBuffer, sampleRate: 16000) else {
            completion(.failure(TranscriptionError.audioConversionFailed))
            return
        }

        // Encode audio as base64
        let base64Audio = wavData.base64EncodedString()

        // Construct request body
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "text": "Transcribe the speech from this audio. Provide only the transcription text, without any additional commentary."
                        ],
                        [
                            "inline_data": [
                                "mime_type": "audio/wav",
                                "data": base64Audio
                            ]
                        ]
                    ]
                ]
            ]
        ]

        // Convert to JSON
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            completion(.failure(TranscriptionError.requestFailed(statusCode: 0, message: "Failed to create JSON request")))
            return
        }

        // Make API request using Gemini 2.5 Flash
        let apiURL = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(apiKey)")!
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        let task = URLSession.shared.dataTask(with: request) { data, response, err in
            if let err = err {
                completion(.failure(err))
                return
            }

            guard let data = data else {
                completion(.failure(TranscriptionError.requestFailed(statusCode: 0, message: "No data received")))
                return
            }

            // Check HTTP status
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                completion(.failure(TranscriptionError.requestFailed(statusCode: httpResponse.statusCode, message: errorMessage)))
                return
            }

            // Parse response
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(GenerateContentResponse.self, from: data)

                if let blockReason = response.promptFeedback?.blockReason {
                    completion(.failure(TranscriptionError.blocked(reason: blockReason)))
                    return
                }

                if let text = response.candidates?.first?.content?.parts?.first?.text {
                    completion(.success(text))
                } else {
                    completion(.failure(TranscriptionError.noTranscriptionInResponse))
                }
            } catch {
                completion(.failure(error))
            }
        }

        task.resume()
    }

    // MARK: - Private Helpers

    private func loadApiKey() -> String? {
        // Check environment variable first
        if let envKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] {
            return envKey
        }

        // Try to read from .env file
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

    /// Convert Float audio buffer to WAV format Data
    private func convertToWAV(audioBuffer: [Float], sampleRate: Int) -> Data? {
        // Convert Float samples to Int16 PCM
        let int16Samples: [Int16] = audioBuffer.map { sample in
            let clampedSample = max(-1.0, min(1.0, sample))
            return Int16(clampedSample * Float(Int16.max))
        }

        // Create WAV header
        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = UInt32(sampleRate) * UInt32(numChannels) * UInt32(bitsPerSample) / 8
        let blockAlign = numChannels * bitsPerSample / 8
        let dataSize = UInt32(int16Samples.count * 2)
        let chunkSize = 36 + dataSize

        var wavData = Data()

        // RIFF header
        wavData.append("RIFF".data(using: .ascii)!)
        wavData.append(UInt32(chunkSize).littleEndianData)
        wavData.append("WAVE".data(using: .ascii)!)

        // fmt chunk
        wavData.append("fmt ".data(using: .ascii)!)
        wavData.append(UInt32(16).littleEndianData) // fmt chunk size
        wavData.append(UInt16(1).littleEndianData)  // PCM format
        wavData.append(numChannels.littleEndianData)
        wavData.append(UInt32(sampleRate).littleEndianData)
        wavData.append(byteRate.littleEndianData)
        wavData.append(blockAlign.littleEndianData)
        wavData.append(bitsPerSample.littleEndianData)

        // data chunk
        wavData.append("data".data(using: .ascii)!)
        wavData.append(dataSize.littleEndianData)

        // Append audio samples
        for sample in int16Samples {
            wavData.append(sample.littleEndianData)
        }

        return wavData
    }
}

// Extension to convert integers to little-endian Data
extension FixedWidthInteger {
    var littleEndianData: Data {
        var value = self.littleEndian
        return Data(bytes: &value, count: MemoryLayout<Self>.size)
    }
}
