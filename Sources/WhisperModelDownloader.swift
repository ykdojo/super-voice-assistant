import Foundation
import WhisperKit

/// WhisperKit model downloader supporting all three models
class WhisperModelDownloader {
    
    /// Download any WhisperKit model by name
    static func downloadModel(modelName: String) async throws -> URL {
        print("Starting download of \(modelName)...")
        
        // Download the model
        let whisperKit = try await WhisperKit(
            model: modelName,
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
    
    /// Download DistilWhisper V3 model (fast English-only)
    static func downloadDistilWhisperV3() async throws -> URL {
        return try await downloadModel(modelName: "distil-whisper_distil-large-v3")
    }
    
    /// Download Large V3 Turbo model (balanced multilingual)
    static func downloadLargeV3Turbo() async throws -> URL {
        return try await downloadModel(modelName: "openai_whisper-large-v3-v20240930_turbo")
    }
    
    /// Download Large V3 model (highest accuracy)
    static func downloadLargeV3() async throws -> URL {
        return try await downloadModel(modelName: "openai_whisper-large-v3-v20240930")
    }
    
    /// Download model based on ModelInfo
    static func downloadModel(from modelInfo: ModelInfo) async throws -> URL {
        return try await downloadModel(modelName: modelInfo.whisperKitModelName)
    }
}
