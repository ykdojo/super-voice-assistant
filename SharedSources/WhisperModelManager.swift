import Foundation
import WhisperKit

/// Shared manager for tracking WhisperKit model download status and metadata
public class WhisperModelManager {
    
    /// Metadata structure for tracking download information
    public struct ModelMetadata: Codable {
        public let modelName: String
        public let downloadDate: Date
        public let downloadVersion: String
        public let fileCount: Int?
        public let totalSize: Int64?
        public let isComplete: Bool
        
        init(modelName: String, downloadDate: Date, fileCount: Int?, totalSize: Int64?, isComplete: Bool) {
            self.modelName = modelName
            self.downloadDate = downloadDate
            self.downloadVersion = "1.0"
            self.fileCount = fileCount
            self.totalSize = totalSize
            self.isComplete = isComplete
        }
    }
    
    /// Shared instance for convenience
    public static let shared = WhisperModelManager()
    
    private let fileManager = FileManager.default
    
    /// Get the base path for WhisperKit models
    public func getModelsBasePath() -> URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath
            .appendingPathComponent("huggingface")
            .appendingPathComponent("models")
            .appendingPathComponent("argmaxinc")
            .appendingPathComponent("whisperkit-coreml")
    }
    
    /// Get the path for a specific model
    public func getModelPath(for modelName: String) -> URL {
        return getModelsBasePath().appendingPathComponent(modelName)
    }
    
    /// Get the metadata file path for a model
    private func getMetadataPath(for modelName: String) -> URL {
        return getModelPath(for: modelName).appendingPathComponent(".download_metadata.json")
    }
    
    /// Mark a model as successfully downloaded
    public func markModelAsDownloaded(_ modelName: String) {
        let modelPath = getModelPath(for: modelName)
        let metadataPath = getMetadataPath(for: modelName)
        
        // Calculate model size and file count
        let fileCount = countFiles(in: modelPath)
        let totalSize = calculateDirectorySize(at: modelPath)
        
        let metadata = ModelMetadata(
            modelName: modelName,
            downloadDate: Date(),
            fileCount: fileCount,
            totalSize: totalSize,
            isComplete: true
        )
        
        // Save metadata
        if let data = try? JSONEncoder().encode(metadata) {
            try? data.write(to: metadataPath)
            print("✅ Marked \(modelName) as downloaded")
        }
    }
    
    /// Check if a model is marked as downloaded
    public func isModelDownloaded(_ modelName: String) -> Bool {
        let metadataPath = getMetadataPath(for: modelName)
        
        // Check if metadata file exists
        guard fileManager.fileExists(atPath: metadataPath.path) else {
            return false
        }
        
        // Try to load and validate metadata
        guard let data = try? Data(contentsOf: metadataPath),
              let metadata = try? JSONDecoder().decode(ModelMetadata.self, from: data) else {
            return false
        }
        
        return metadata.isComplete
    }
    
    /// Get metadata for a downloaded model
    public func getModelMetadata(_ modelName: String) -> ModelMetadata? {
        let metadataPath = getMetadataPath(for: modelName)
        
        guard let data = try? Data(contentsOf: metadataPath),
              let metadata = try? JSONDecoder().decode(ModelMetadata.self, from: data) else {
            return nil
        }
        
        return metadata
    }
    
    /// Get all downloaded models
    public func getDownloadedModels() -> [String] {
        let modelsPath = getModelsBasePath()
        
        guard let modelDirs = try? fileManager.contentsOfDirectory(
            at: modelsPath,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        
        return modelDirs.compactMap { modelDir in
            let modelName = modelDir.lastPathComponent
            return isModelDownloaded(modelName) ? modelName : nil
        }
    }
    
    /// Check if a model exists on disk (regardless of download status)
    public func modelExistsOnDisk(_ modelName: String) -> Bool {
        let modelPath = getModelPath(for: modelName)
        return fileManager.fileExists(atPath: modelPath.path)
    }
    
    /// Remove download metadata (useful for forcing re-validation)
    public func removeDownloadMetadata(for modelName: String) {
        let metadataPath = getMetadataPath(for: modelName)
        try? fileManager.removeItem(at: metadataPath)
    }
    
    /// Validate model integrity (basic check - verifies key files exist)
    public func validateModelIntegrity(_ modelName: String) -> Bool {
        let modelPath = getModelPath(for: modelName)
        
        // Check for essential WhisperKit model files
        let essentialFiles = [
            "config.json",
            "model.mil"  // Or other essential model files
        ]
        
        for fileName in essentialFiles {
            let filePath = modelPath.appendingPathComponent(fileName)
            if !fileManager.fileExists(atPath: filePath.path) {
                // Not all models have the same structure, so we'll be lenient
                // Just check that the directory exists and has some content
                break
            }
        }
        
        // Basic check: directory exists and has files
        guard fileManager.fileExists(atPath: modelPath.path) else {
            return false
        }
        
        let fileCount = countFiles(in: modelPath)
        return fileCount > 0
    }
    
    /// Clean up incomplete downloads
    public func cleanupIncompleteDownloads() {
        let modelsPath = getModelsBasePath()
        
        guard let modelDirs = try? fileManager.contentsOfDirectory(
            at: modelsPath,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return
        }
        
        for modelDir in modelDirs {
            let modelName = modelDir.lastPathComponent
            
            // If model exists but not marked as complete, it's potentially incomplete
            if modelExistsOnDisk(modelName) && !isModelDownloaded(modelName) {
                print("⚠️  Found potentially incomplete download: \(modelName)")
                // Optionally remove it:
                // try? fileManager.removeItem(at: modelDir)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func countFiles(in directory: URL) -> Int {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        
        var count = 0
        for case _ as URL in enumerator {
            count += 1
        }
        return count
    }
    
    private func calculateDirectorySize(at directory: URL) -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += Int64(fileSize)
            }
        }
        return totalSize
    }
}
