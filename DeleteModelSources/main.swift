import Foundation
import SharedModels

// Delete a specific WhisperKit model
print("🗑️  WhisperKit Single Model Delete Tool")
print("=" * 40)

// Get command line arguments
let arguments = CommandLine.arguments
if arguments.count < 2 {
    print("❌ Usage: swift run DeleteModel <model-name>")
    print("")
    print("Available models:")
    for model in ModelData.availableModels {
        print("  • \(model.name)")
    }
    exit(1)
}

let modelNameToDelete = arguments[1]

// Get the models directory path
let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
let modelsPath = documentsPath
    .appendingPathComponent("huggingface")
    .appendingPathComponent("models")
    .appendingPathComponent("argmaxinc")
    .appendingPathComponent("whisperkit-coreml")

print("📁 Models directory: \(modelsPath.path)")
print("")

// Find the model to delete
if let modelInfo = ModelData.availableModels.first(where: { $0.name == modelNameToDelete }) {
    let modelPath = modelsPath.appendingPathComponent(modelInfo.whisperKitModelName)
    
    if FileManager.default.fileExists(atPath: modelPath.path) {
        do {
            // Calculate size before deletion
            let size = try FileManager.default.allocatedSizeOfDirectory(at: modelPath)
            let sizeInMB = Double(size) / 1024 / 1024
            
            print("Found model: \(modelInfo.displayName)")
            print("  • WhisperKit name: \(modelInfo.whisperKitModelName)")
            print("  • Size: \(String(format: "%.1f", sizeInMB)) MB")
            print("")
            
            print("⚠️  Are you sure you want to delete this model? (y/N): ", terminator: "")
            
            if let response = readLine()?.lowercased(), response == "y" {
                print("")
                print("🗑️  Deleting \(modelInfo.displayName)...", terminator: "")
                
                try FileManager.default.removeItem(at: modelPath)
                
                // Also remove metadata if it exists
                let metadataPath = modelPath.appendingPathComponent(".download_metadata.json")
                if FileManager.default.fileExists(atPath: metadataPath.path) {
                    try? FileManager.default.removeItem(at: metadataPath)
                }
                
                print(" ✅")
                print("")
                print("✅ Model deleted successfully!")
            } else {
                print("❌ Deletion cancelled")
            }
        } catch {
            print("❌ Error deleting model: \(error.localizedDescription)")
        }
    } else {
        print("❌ Model '\(modelInfo.displayName)' is not downloaded")
        print("   Path does not exist: \(modelPath.path)")
    }
} else {
    print("❌ Unknown model: '\(modelNameToDelete)'")
    print("")
    print("Available models:")
    for model in ModelData.availableModels {
        print("  • \(model.name) - \(model.displayName)")
    }
}

// Extension to calculate directory size
extension FileManager {
    func allocatedSizeOfDirectory(at directoryURL: URL) throws -> UInt64 {
        var size: UInt64 = 0
        
        let allocatedSizeResourceKeys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .fileAllocatedSizeKey,
            .totalFileAllocatedSizeKey,
        ]
        
        let enumerator = self.enumerator(at: directoryURL,
                                        includingPropertiesForKeys: Array(allocatedSizeResourceKeys),
                                        options: [.skipsHiddenFiles],
                                        errorHandler: nil)!
        
        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: allocatedSizeResourceKeys)
            
            if resourceValues.isRegularFile ?? false {
                size += UInt64(resourceValues.totalFileAllocatedSize ?? resourceValues.fileAllocatedSize ?? 0)
            }
        }
        
        return size
    }
}

// Extension for string multiplication
extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}