import Foundation

public final class SixtyDBAudioTranscriber: NSObject, URLSessionTaskDelegate {
  public enum TranscriptionError: Error, LocalizedError {
    case missingKey, invalidAudio, invalidResponse
    case httpStatus(Int)

    public var errorDescription: String? {
      switch self {
      case .missingKey:
        return "60db workspace key not found in SIXTYDB_API_KEY or keychain service sixtydb-api-key"
      case .invalidAudio: return "60db requires nonempty audio of at most 10 MB"
      case .invalidResponse: return "60db returned an invalid transcript response"
      case .httpStatus(let status): return "60db transcription failed (HTTP \(status))"
      }
    }
  }

  private let configuration: URLSessionConfiguration

  public init(configuration: URLSessionConfiguration = .ephemeral) {
    let sessionConfiguration = configuration.copy() as! URLSessionConfiguration
    sessionConfiguration.timeoutIntervalForResource = 60
    self.configuration = sessionConfiguration
    super.init()
  }

  public func transcribe(
    audioBuffer: [Float], completion: @escaping (Result<String, Error>) -> Void
  ) {
    guard
      let key = GeminiAPIKey.resolve(
        environmentVariable: "SIXTYDB_API_KEY", keychainService: "sixtydb-api-key")?
        .trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty
    else {
      completion(.failure(TranscriptionError.missingKey))
      return
    }
    guard !audioBuffer.isEmpty, audioBuffer.count <= (10_000_000 - 44) / 2,
      let wav = GeminiAudioTranscriber.convertToWAV(audioBuffer: audioBuffer, sampleRate: 16000)
    else {
      completion(.failure(TranscriptionError.invalidAudio))
      return
    }
    let request = Self.makeRequest(wav: wav, apiKey: key)
    let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    session.dataTask(with: request) { data, response, error in
      defer { session.finishTasksAndInvalidate() }
      if let error = error {
        completion(.failure(error))
        return
      }
      do {
        completion(.success(try Self.transcript(data: data, response: response)))
      } catch {
        completion(.failure(error))
      }
    }.resume()
  }

  static func makeRequest(wav: Data, apiKey: String) -> URLRequest {
    let boundary = "audio-\(UUID().uuidString)"
    var body = Data(
      "--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\nContent-Type: audio/wav\r\n\r\n"
        .utf8)
    body.append(wav)
    body.append(Data("\r\n--\(boundary)--\r\n".utf8))
    var request = URLRequest(url: URL(string: "https://api.60db.ai/stt")!)
    request.httpMethod = "POST"
    request.timeoutInterval = 60
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue(
      "multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    request.httpBody = body
    return request
  }

  static func transcript(data: Data?, response: URLResponse?) throws -> String {
    guard let http = response as? HTTPURLResponse else { throw TranscriptionError.invalidResponse }
    guard (200..<300).contains(http.statusCode) else {
      throw TranscriptionError.httpStatus(http.statusCode)
    }
    guard let data = data,
      let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      result["success"] as? Bool != false,
      result["error"] == nil, result["error_code"] == nil,
      let text = result["text"] as? String
    else { throw TranscriptionError.invalidResponse }
    return text
  }

  public func urlSession(
    _ session: URLSession, task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
    completionHandler: @escaping (URLRequest?) -> Void
  ) {
    completionHandler(nil)
  }
}
