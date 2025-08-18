import Foundation
import WhisperKit

/// Simple WhisperKit downloader for testing DistilWhisperV3
class WhisperModelDownloader {
    
    /// Download DistilWhisperV3 model
    static func downloadDistilWhisperV3() async throws -> URL {
        print("Starting download of DistilWhisper V3...")
        
        // Download the model
        let whisperKit = try await WhisperKit(
            model: "distil-whisper_distil-large-v3",
            modelFolder: nil,
            tokenizerFolder: nil,
            download: true
        )
        
        // Get the model folder path
        guard let modelFolder = whisperKit.modelFolder else {
            throw NSError(domain: "WhisperModelDownloader", code: -1, 
                        userInfo: [NSLocalizedDescriptionKey: "Model folder not found after download"])
        }
        
        print("Model downloaded successfully to: \(modelFolder)")
        return modelFolder
    }
}
