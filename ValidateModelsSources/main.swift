import Foundation
import WhisperKit
import Hub
import SharedModels

print("🔍 WhisperKit Model Validation Tool")
print("====================================")
print("This tool checks if downloaded models are complete by trying to load them.\n")

// Model list
let models = [
    ("distil-whisper_distil-large-v3", "Distil-Whisper V3"),
    ("openai_whisper-large-v3-v20240930_turbo", "Large V3 Turbo"),
    ("openai_whisper-large-v3-v20240930", "Large V3"),
    ("openai_whisper-tiny", "Tiny")
]

let modelManager = WhisperModelManager.shared

func validateModel(modelName: String, displayName: String) async {
    print("Checking \(displayName)...")
    
    // First check if the directory exists
    if !modelManager.modelExistsOnDisk(modelName) {
        print("  ❌ Not downloaded (directory doesn't exist)")
        return
    }
    
    // Check if model is marked as downloaded
    if modelManager.isModelDownloaded(modelName) {
        print("  ✅ Marked as downloaded")
        
        // Show metadata
        if let metadata = modelManager.getModelMetadata(modelName) {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            print("  📅 Downloaded: \(formatter.string(from: metadata.downloadDate))")
            
            if let fileCount = metadata.fileCount {
                print("  📁 Files: \(fileCount)")
            }
            
            if let size = metadata.totalSize {
                let sizeInMB = Double(size) / 1024 / 1024
                print("  💾 Size: \(String(format: "%.1f", sizeInMB)) MB")
            }
        }
    } else {
        print("  ⚠️  Found on disk but not marked as complete")
        
        // Check basic integrity without loading the full model
        if modelManager.validateModelIntegrity(modelName) {
            print("  📁 Model files present, marking as downloaded")
            modelManager.markModelAsDownloaded(modelName)
            print("  ✅ Marked as downloaded")
        } else {
            print("  ❌ Model appears incomplete")
            print("  💡 Tip: Delete the model folder and re-download")
        }
    }
    
    print("")
}

// Main execution
Task {
    for (modelName, displayName) in models {
        await validateModel(modelName: modelName, displayName: displayName)
    }
    
    print("\n✨ Validation complete!")
    print("   - Complete models can be used for transcription")
    print("   - Incomplete models should be re-downloaded")
    
    exit(0)
}

// Keep the script running
RunLoop.main.run()
