import Foundation

// Delete all downloaded WhisperKit models
print("🗑️  WhisperKit Model Cleanup Tool")
print("=" * 40)

// Get the models directory path
let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
let modelsPath = documentsPath
    .appendingPathComponent("huggingface")
    .appendingPathComponent("models")
    .appendingPathComponent("argmaxinc")
    .appendingPathComponent("whisperkit-coreml")

print("📁 Models directory: \(modelsPath.path)")
print("")

// Check if the directory exists
if FileManager.default.fileExists(atPath: modelsPath.path) {
    do {
        // List all model directories
        let modelDirs = try FileManager.default.contentsOfDirectory(at: modelsPath, 
                                                                   includingPropertiesForKeys: nil,
                                                                   options: [.skipsHiddenFiles])
        
        if modelDirs.isEmpty {
            print("✅ No models found to delete")
        } else {
            print("Found \(modelDirs.count) model(s):")
            print("")
            
            // Display models and their sizes
            for modelDir in modelDirs {
                let modelName = modelDir.lastPathComponent
                
                // Calculate size
                let size = try FileManager.default.allocatedSizeOfDirectory(at: modelDir)
                let sizeInMB = Double(size) / 1024 / 1024
                
                print("  • \(modelName)")
                print("    Size: \(String(format: "%.1f", sizeInMB)) MB")
            }
            
            print("")
            print("⚠️  Are you sure you want to delete all models? (y/N): ", terminator: "")
            
            if let response = readLine()?.lowercased(), response == "y" {
                print("")
                print("Deleting models...")
                
                for modelDir in modelDirs {
                    let modelName = modelDir.lastPathComponent
                    print("  🗑️  Deleting \(modelName)...", terminator: "")
                    try FileManager.default.removeItem(at: modelDir)
                    print(" ✅")
                }
                
                print("")
                print("✅ All models deleted successfully!")
            } else {
                print("❌ Deletion cancelled")
            }
        }
    } catch {
        print("❌ Error: \(error.localizedDescription)")
    }
} else {
    print("✅ No models directory found - nothing to delete")
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
