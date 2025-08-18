import Foundation
import WhisperKit
import SharedModels

print("🧪 Testing WhisperKit Model Downloads")
print("=====================================")

// Model configurations
var models = [
    ("distil-whisper_distil-large-v3", "Distil-Whisper V3 (Fast English)"),
    ("openai_whisper-large-v3-v20240930_turbo", "Large V3 Turbo (Balanced)"),
    ("openai_whisper-large-v3-v20240930", "Large V3 (Highest Accuracy)")
]

// Add tiny model for testing in debug builds
#if DEBUG
models.append(("openai_whisper-tiny", "Tiny (Test Only - 39MB)"))
#endif

class WhisperModelDownloader {
    static let modelManager = WhisperModelManager.shared
    
    static func downloadModel(modelName: String, displayName: String, forceRedownload: Bool = false) async throws -> URL {
        print("\n📦 Testing: \(displayName)")
        print("   Model ID: \(modelName)")
        print("   Starting download...")
        
        let modelPath = modelManager.getModelPath(for: modelName)
        
        // Check if model is already marked as downloaded
        if modelManager.isModelDownloaded(modelName) && !forceRedownload {
            print("   ✅ Model already downloaded and verified")
            print("   ℹ️ Location: \(modelPath)")
            
            // Show metadata if available
            if let metadata = modelManager.getModelMetadata(modelName) {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                print("   📅 Downloaded: \(formatter.string(from: metadata.downloadDate))")
                if let size = metadata.totalSize {
                    let sizeInMB = Double(size) / 1024 / 1024
                    print("   💾 Size: \(String(format: "%.1f", sizeInMB)) MB")
                }
            }
            
            print("   💡 Tip: Use --force flag to re-download")
            return modelPath
        }
        
        // Check if model exists but not marked as complete
        if modelManager.modelExistsOnDisk(modelName) && !modelManager.isModelDownloaded(modelName) {
            print("   ⚠️  Found incomplete download, re-downloading...")
            try FileManager.default.removeItem(at: modelPath)
        }
        
        // Remove existing model if force redownload
        if forceRedownload && FileManager.default.fileExists(atPath: modelPath.path) {
            print("   🗑️ Removing existing model for re-download...")
            modelManager.removeDownloadMetadata(for: modelName)
            try FileManager.default.removeItem(at: modelPath)
        }
        
        // Download with progress tracking
        var lastFractionCompleted: Double = 0
        print("   ⏳ Downloading (this may take a few minutes)...")
        
        let modelFolder = try await WhisperKit.download(
            variant: modelName,
            from: "argmaxinc/whisperkit-coreml",
            progressCallback: { progress in
                // Only print if progress has increased by at least 0.001
                if progress.fractionCompleted - lastFractionCompleted >= 0.001 {
                    lastFractionCompleted = progress.fractionCompleted
                    
                    // Debug: print all progress properties
                    // print("\n🔍 DEBUG - Progress object:")
                    // print("   fractionCompleted: \(progress.fractionCompleted)")
                    // print("   totalUnitCount: \(progress.totalUnitCount)")
                    // print("   completedUnitCount: \(progress.completedUnitCount)")
                    // print("   localizedDescription: \(progress.localizedDescription ?? "nil")")
                    // print("   localizedAdditionalDescription: \(progress.localizedAdditionalDescription ?? "nil")")
                    // print("   isFinished: \(progress.isFinished)")
                    // print("   isCancelled: \(progress.isCancelled)")
                    // print("   isPaused: \(progress.isPaused)")
                    // print("   isIndeterminate: \(progress.isIndeterminate)")
                    
                    let percentage = progress.fractionCompleted * 100
                    let percentageInt = Int(percentage)
                    let progressBar = makeProgressBar(percentage: percentageInt)
                    print("\r   \(progressBar) \(String(format: "%.1f", percentage))%", terminator: "")
                    fflush(stdout)
                }
            }
        )
        
        print() // Add newline after progress bar
        
        // Mark model as successfully downloaded
        modelManager.markModelAsDownloaded(modelName)
        
        print("   ✅ Downloaded successfully to: \(modelFolder)")
        print("   ✅ Model marked as complete")
        return modelFolder
    }
    
    static func makeProgressBar(percentage: Int, width: Int = 30) -> String {
        let filled = Int(Double(width) * Double(percentage) / 100.0)
        let empty = width - filled
        let bar = String(repeating: "█", count: filled) + String(repeating: "░", count: empty)
        return "[\(bar)]"
    }
}

// Parse command line arguments
let args = CommandLine.arguments
var modelIndex: Int? = nil
var forceRedownload = false

for (index, arg) in args.enumerated() {
    if arg == "--force" || arg == "-f" {
        forceRedownload = true
    } else if index > 0 && Int(arg) != nil {
        modelIndex = Int(arg)
    }
}

Task {
    do {
        if let index = modelIndex, index >= 1 && index <= models.count {
            // Test specific model
            let (modelName, displayName) = models[index - 1]
            let modelPath = try await WhisperModelDownloader.downloadModel(
                modelName: modelName, 
                displayName: displayName,
                forceRedownload: forceRedownload
            )
            print("\n✅ Success! Model at: \(modelPath)")
        } else {
            // Show menu
            print("\nSelect a model to test:")
            for (index, (_, displayName)) in models.enumerated() {
                print("\(index + 1). \(displayName)")
            }
            print("\nUsage: swift run TestDownload [1-\(models.count)] [--force]")
            print("Example: swift run TestDownload 1")
            print("         swift run TestDownload 1 --force  (re-download even if exists)")
            
            // Test all models if no argument provided
            print("\n🔄 Testing all models sequentially...")
            for (modelName, displayName) in models {
                _ = try await WhisperModelDownloader.downloadModel(
                    modelName: modelName,
                    displayName: displayName,
                    forceRedownload: forceRedownload
                )
            }
            print("\n✅ All models downloaded successfully!")
        }
        exit(0)
    } catch {
        print("\n❌ Failed: \(error)")
        exit(1)
    }
}

RunLoop.main.run()
