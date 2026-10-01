import Foundation

final class TestTransport: URLProtocol {
  static var requests: [URLRequest] = []
  static var status = 200
  static var responseData = Data("{\"text\":\"hello\"}".utf8)
  static var failure: Error?

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    Self.requests.append(request)
    if let failure = Self.failure {
      client?.urlProtocol(self, didFailWithError: failure)
      return
    }
    let response = HTTPURLResponse(
      url: request.url!, statusCode: Self.status, httpVersion: nil, headerFields: nil)!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Self.responseData)
    client?.urlProtocolDidFinishLoading(self)
  }
  override func stopLoading() {}
}

@main
struct Check {
  static func main() async throws {
    setenv("SIXTYDB_API_KEY", " test-workspace-key ", 1)
    defer { unsetenv("SIXTYDB_API_KEY") }
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [TestTransport.self]
    let transcriber = SixtyDBAudioTranscriber(configuration: configuration)
    func transcribe(_ samples: [Float]) async -> Result<String, Error> {
      await withCheckedContinuation { continuation in
        transcriber.transcribe(audioBuffer: samples) { continuation.resume(returning: $0) }
      }
    }
    let wav = GeminiAudioTranscriber.convertToWAV(
      audioBuffer: [0, .nan, .infinity, -1, 1], sampleRate: 16000)!
    precondition(wav.count == 54)
    precondition(String(data: wav.prefix(4), encoding: .ascii) == "RIFF")
    precondition(Array(wav[44..<50]) == [0, 0, 0, 0, 0, 0])
    let request = SixtyDBAudioTranscriber.makeRequest(wav: wav, apiKey: "key")
    precondition(request.url!.absoluteString == "https://api.60db.ai/stt")
    precondition(request.httpMethod == "POST" && request.timeoutInterval == 60)
    let contentType = request.value(forHTTPHeaderField: "Content-Type")!
    let boundary = contentType.components(separatedBy: "boundary=")[1]
    let body = request.httpBody!
    precondition(body.range(of: wav) != nil)
    precondition(
      body.suffix(Data("--\(boundary)--\r\n".utf8).count) == Data("--\(boundary)--\r\n".utf8))
    precondition(String(decoding: body, as: UTF8.self).contains("filename=\"audio.wav\""))

    let text = try await transcribe([0.5, -0.5]).get()
    precondition(text == "hello" && TestTransport.requests.count == 1)
    precondition(
      TestTransport.requests[0].value(forHTTPHeaderField: "Authorization")
        == "Bearer test-workspace-key")
    TestTransport.responseData = Data(
      "{\"text\":\"\",\"warning_codes\":[\"no_speech_detected\"]}".utf8)
    let silence = try await transcribe([0]).get()
    precondition(silence.isEmpty)
    for invalid in [
      "null", "[]", "{}", "not JSON", "{\"text\":5}", "{\"text\":\"bad\",\"success\":false}",
    ] {
      TestTransport.responseData = Data(invalid.utf8)
      if case .success = await transcribe([0]) { fatalError("Accepted invalid transcript") }
    }
    for status in [401, 402, 429, 503] {
      TestTransport.status = status
      TestTransport.responseData = Data("private-response-details".utf8)
      let count = TestTransport.requests.count
      let result = await transcribe([0])
      guard case .failure(let error) = result else { fatalError("Accepted HTTP error") }
      precondition(error.localizedDescription.contains("\(status)"))
      precondition(!error.localizedDescription.contains("private-response"))
      precondition(TestTransport.requests.count == count + 1)
    }
    let count = TestTransport.requests.count
    for samples in [[], Array(repeating: Float(0), count: 5_000_000)] {
      if case .success = await transcribe(samples) { fatalError("Accepted invalid audio") }
    }
    setenv("SIXTYDB_API_KEY", " ", 1)
    if case .success = await transcribe([0]) { fatalError("Accepted blank key") }
    precondition(TestTransport.requests.count == count)
    setenv("SIXTYDB_API_KEY", "test-key", 1)
    TestTransport.failure = URLError(.timedOut)
    if case .success = await transcribe([0]) { fatalError("Accepted timeout") }
    precondition(TestTransport.requests.count == count + 1)
    var redirectAccepted = true
    let session = URLSession(configuration: configuration)
    defer { session.invalidateAndCancel() }
    transcriber.urlSession(
      session, task: session.dataTask(with: request),
      willPerformHTTPRedirection: HTTPURLResponse(
        url: request.url!, statusCode: 302, httpVersion: nil, headerFields: nil)!,
      newRequest: URLRequest(url: URL(string: "https://other.example/")!)
    ) { redirectAccepted = $0 != nil }
    precondition(!redirectAccepted)
    setenv("GEMINI_API_KEY", "gemini-test-key", 1)
    defer { unsetenv("GEMINI_API_KEY") }
    precondition(GeminiAPIKey.resolve() == "gemini-test-key")
    print("60db native request, WAV, response and failure checks passed")
  }
}
