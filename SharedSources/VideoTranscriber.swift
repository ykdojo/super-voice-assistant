import Foundation

/// Transcribes video files using Gemini API
public class VideoTranscriber {

    public init() {}

    public enum TranscriptionError: Error, LocalizedError {
        case apiKeyNotFound
        case fileNotFound
        case readFailed
        case requestFailed(statusCode: Int, message: String)
        case noTranscriptionInResponse
        case blocked(reason: String)

        public var errorDescription: String? {
            switch self {
            case .apiKeyNotFound:
                return "GEMINI_API_KEY not found in environment or .env file"
            case .fileNotFound:
                return "Video file not found"
            case .readFailed:
                return "Failed to read video file"
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

    /// Transcribe a video file using Gemini API
    /// - Parameters:
    ///   - videoURL: URL to the video file
    ///   - completion: Completion handler with transcription result
    public func transcribe(videoURL: URL, completion: @escaping (Result<String, Error>) -> Void) {
        // Load API key
        guard let apiKey = loadApiKey() else {
            completion(.failure(TranscriptionError.apiKeyNotFound))
            return
        }

        // Check if file exists
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            completion(.failure(TranscriptionError.fileNotFound))
            return
        }

        // Read video file
        guard let videoData = try? Data(contentsOf: videoURL) else {
            completion(.failure(TranscriptionError.readFailed))
            return
        }

        // Determine MIME type
        let mimeType = getMimeType(for: videoURL.pathExtension)

        // Encode video as base64
        let base64Video = videoData.base64EncodedString()

        // Construct request body
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "text": "Transcribe the speech from this video. Provide only the transcription text, without any additional commentary."
                        ],
                        [
                            "inline_data": [
                                "mime_type": mimeType,
                                "data": base64Video
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

        // Make API request
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

    private func getMimeType(for fileExtension: String) -> String {
        switch fileExtension.lowercased() {
        case "mp4":
            return "video/mp4"
        case "mov":
            return "video/quicktime"
        case "avi":
            return "video/x-msvideo"
        default:
            return "video/mp4"
        }
    }
}
