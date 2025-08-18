import Foundation
import WhisperKit
import Hub

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

func getModelPath(for whisperKitModelName: String) -> URL {
    // Use the same path structure as WhisperKit/HubApi
    let hubApi = HubApi()
    let repo = Hub.Repo(id: "argmaxinc/whisperkit-coreml", type: .models)
    let repoLocation = hubApi.localRepoLocation(repo)
    return repoLocation.appendingPathComponent(whisperKitModelName)
}

func validateModel(modelName: String, displayName: String) async {
    print("Checking \(displayName)...")
    
    let modelPath = getModelPath(for: modelName)
    
    // First check if the directory exists
    if !FileManager.default.fileExists(atPath: modelPath.path) {
        print("  ❌ Not downloaded (directory doesn't exist)")
        return
    }
    
    // Try to load the model with WhisperKit
    do {
        print("  📂 Found at: \(modelPath.path)")
        print("  🔄 Attempting to load with WhisperKit...")
        
        // Try to initialize WhisperKit with the specific model folder
        let whisperKit = try await WhisperKit(
            modelFolder: modelPath.path,
            verbose: false,
            logLevel: .error,
            load: true
        )
        
        print("  ✅ Model is complete and valid!")
        
    } catch {
        print("  ⚠️  Model is incomplete or corrupted!")
        print("     Error: \(error.localizedDescription)")
        print("  💡 Tip: Delete the model folder and re-download")
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
