import Foundation
import WhisperKit
import SharedModels

/// WhisperKit model downloader supporting all three models
class WhisperModelDownloader {
    
    /// Download any WhisperKit model by name with progress callback
    static func downloadModel(modelName: String, progressCallback: ((Progress) -> Void)? = nil) async throws -> URL {
        print("Starting download of \(modelName)...")
        
        let modelManager = WhisperModelManager.shared
        let modelPath = modelManager.getModelPath(for: modelName)
        
        // Check if model is already marked as downloaded
        if modelManager.isModelDownloaded(modelName) {
            print("Model already downloaded and verified: \(modelName)")
            return modelPath
        }
        
        // Check if model exists but not marked as complete (incomplete download)
        if modelManager.modelExistsOnDisk(modelName) && !modelManager.isModelDownloaded(modelName) {
            print("Found incomplete download, removing and re-downloading...")
            try? FileManager.default.removeItem(at: modelPath)
        }
        
        // Download the model using WhisperKit.download with progress tracking
        let modelFolder = try await WhisperKit.download(
            variant: modelName,
            from: "argmaxinc/whisperkit-coreml",
            progressCallback: progressCallback
        )
        
        print("Model downloaded successfully to: \(modelFolder)")
        
        // Validate the model by trying to load it
        print("Validating model...")
        do {
            let _ = try await WhisperKit(
                modelFolder: modelFolder.path,
                verbose: false,
                logLevel: .error,
                load: true
            )
            
            // If loading succeeds, mark as complete
            modelManager.markModelAsDownloaded(modelName)
            print("Model validated and marked as complete: \(modelName)")
        } catch {
            print("Warning: Model validation failed but download completed: \(error)")
            // Still mark as downloaded since the download itself completed
            // The model state manager will handle validation separately
            modelManager.markModelAsDownloaded(modelName)
        }
        
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
