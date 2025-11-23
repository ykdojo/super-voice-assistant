#!/usr/bin/env swift

import Foundation

// MARK: - API Key Loading
func loadApiKey() -> String? {
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

// MARK: - Response Models
struct GenerateContentResponse: Codable {
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

// MARK: - Main Script
print("🎬 Gemini Video Transcription")
print("============================\n")

// Get video path from command line argument
guard CommandLine.arguments.count > 1 else {
    print("❌ Usage: swift run TranscribeVideo <path-to-video>")
    exit(1)
}

let videoPath = CommandLine.arguments[1]
let videoURL = URL(fileURLWithPath: videoPath)

// Check if file exists
guard FileManager.default.fileExists(atPath: videoURL.path) else {
    print("❌ Video file not found: \(videoPath)")
    exit(1)
}

// Load API key
guard let apiKey = loadApiKey() else {
    print("❌ GEMINI_API_KEY not found")
    print("💡 Set environment variable or create .env file")
    exit(1)
}

// Read video file
guard let videoData = try? Data(contentsOf: videoURL) else {
    print("❌ Failed to read video file")
    exit(1)
}

let fileSizeMB = Double(videoData.count) / 1024.0 / 1024.0
print("📹 Video: \(videoURL.lastPathComponent)")
print("📏 Size: \(String(format: "%.2f", fileSizeMB)) MB")
print("🔑 API Key loaded\n")

// Determine MIME type
let mimeType: String
switch videoURL.pathExtension.lowercased() {
case "mp4":
    mimeType = "video/mp4"
case "mov":
    mimeType = "video/quicktime"
case "avi":
    mimeType = "video/x-msvideo"
default:
    mimeType = "video/mp4"
}

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
    print("❌ Failed to create JSON request")
    exit(1)
}

// Make API request
let apiURL = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(apiKey)")!
var request = URLRequest(url: apiURL)
request.httpMethod = "POST"
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
request.httpBody = jsonData

print("🚀 Sending request to Gemini API...")

let semaphore = DispatchSemaphore(value: 0)
var transcription: String?
var error: Error?

let task = URLSession.shared.dataTask(with: request) { data, response, err in
    defer { semaphore.signal() }

    if let err = err {
        error = err
        return
    }

    guard let data = data else {
        error = NSError(domain: "TranscribeVideo", code: 1, userInfo: [NSLocalizedDescriptionKey: "No data received"])
        return
    }

    // Debug: Print raw response
    if let httpResponse = response as? HTTPURLResponse {
        print("📡 Response status: \(httpResponse.statusCode)\n")

        if httpResponse.statusCode != 200 {
            if let responseText = String(data: data, encoding: .utf8) {
                print("❌ Error response:")
                print(responseText)
            }
            error = NSError(domain: "TranscribeVideo", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API request failed"])
            return
        }
    }

    // Parse response
    do {
        let decoder = JSONDecoder()
        let response = try decoder.decode(GenerateContentResponse.self, from: data)

        if let blockReason = response.promptFeedback?.blockReason {
            error = NSError(domain: "TranscribeVideo", code: 2, userInfo: [NSLocalizedDescriptionKey: "Request blocked: \(blockReason)"])
            return
        }

        if let text = response.candidates?.first?.content?.parts?.first?.text {
            transcription = text
        } else {
            error = NSError(domain: "TranscribeVideo", code: 3, userInfo: [NSLocalizedDescriptionKey: "No transcription in response"])
        }
    } catch let parseError {
        error = parseError
    }
}

task.resume()
semaphore.wait()

// Print results
if let error = error {
    print("❌ Error: \(error.localizedDescription)")
    exit(1)
}

if let transcription = transcription {
    print("✅ Transcription:")
    print("─────────────────")
    print(transcription)
    print("─────────────────")
} else {
    print("❌ No transcription received")
    exit(1)
}
