import Foundation
import WhisperKit

/// WhisperKit model downloader supporting all three models
class WhisperModelDownloader {
    
    /// Download any WhisperKit model by name with progress callback
    static func downloadModel(modelName: String, progressCallback: ((Progress) -> Void)? = nil) async throws -> URL {
        print("Starting download of \(modelName)...")
        
        // Download the model using WhisperKit.download with progress tracking
        let modelFolder = try await WhisperKit.download(
            variant: modelName,
            from: "argmaxinc/whisperkit-coreml",
            progressCallback: progressCallback
        )
        
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
    
    /// Download model based on ModelInfo with progress callback
    static func downloadModel(from modelInfo: ModelInfo, progressCallback: ((Progress) -> Void)? = nil) async throws -> URL {
        return try await downloadModel(modelName: modelInfo.whisperKitModelName, progressCallback: progressCallback)
    }
}
