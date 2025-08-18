import Foundation
import WhisperKit

print("🧪 Testing Distil-Whisper V3 Model Download")
print("============================================")

class WhisperModelDownloader {
    static func downloadDistilWhisperV3() async throws -> URL {
        print("Starting download of DistilWhisper V3...")
        
        let whisperKit = try await WhisperKit(
            model: "distil-whisper_distil-large-v3",
            modelFolder: nil,
            tokenizerFolder: nil,
            verbose: true,
            download: true
        )
        
        guard let modelFolder = whisperKit.modelFolder else {
            throw NSError(domain: "WhisperModelDownloader", code: -1, 
                        userInfo: [NSLocalizedDescriptionKey: "Model folder not found after download"])
        }
        
        print("Model downloaded successfully to: \(modelFolder)")
        return modelFolder
    }
}

Task {
    do {
        let modelPath = try await WhisperModelDownloader.downloadDistilWhisperV3()
        print("✅ Success! Model at: \(modelPath)")
        exit(0)
    } catch {
        print("❌ Failed: \(error)")
        exit(1)
    }
}

RunLoop.main.run()
