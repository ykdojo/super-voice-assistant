import Foundation
import SwiftUI
import WhisperKit
import SharedModels

@MainActor
class ModelStateManager: ObservableObject {
    static let shared = ModelStateManager()
    
    @Published var downloadedModels: Set<String> = []
    @Published var isCheckingModels = true  // Start as true to prevent flash
    @Published var selectedModel: String? = nil
    
    private init() {}
    
    func checkDownloadedModels() async {
        // Don't reset to empty - keep existing state until check completes
        var newDownloadedModels: Set<String> = []
        let modelManager = WhisperModelManager.shared
        
        // Process each model in parallel for faster checking
        await withTaskGroup(of: (String, Bool).self) { group in
            for model in ModelData.availableModels {
                let whisperKitModelName = model.whisperKitModelName
                let modelPath = getModelPath(for: whisperKitModelName)
                
                group.addTask {
                    // First check if directory exists
                    if !FileManager.default.fileExists(atPath: modelPath.path) {
                        return (model.name, false)
                    }
                    
                    // Check if we have metadata marking it as complete
                    if modelManager.isModelDownloaded(whisperKitModelName) {
                        // Trust our metadata if it says complete
                        return (model.name, true)
                    }
                    
                    // Try to load the model with WhisperKit to validate it's complete
                    do {
                        let _ = try await WhisperKit(
                            modelFolder: modelPath.path,
                            verbose: false,
                            logLevel: .error,
                            load: true
                        )
                        
                        // If loading succeeded, mark it in our manager
                        modelManager.markModelAsDownloaded(whisperKitModelName)
                        return (model.name, true)
                    } catch {
                        // Model exists but is incomplete or corrupted
                        print("Model \(model.name) exists but is incomplete")
                        return (model.name, false)
                    }
                }
            }
            
            // Collect results
            for await (modelName, isComplete) in group {
                if isComplete {
                    newDownloadedModels.insert(modelName)
                }
            }
        }
        
        // Update the published properties
        await MainActor.run {
            self.downloadedModels = newDownloadedModels
            
            // If no model is selected but we have downloaded models, select the first one
            if self.selectedModel == nil && !newDownloadedModels.isEmpty {
                self.selectedModel = newDownloadedModels.first
            }
            
            self.isCheckingModels = false
        }
    }
    
    func markModelAsDownloaded(_ modelName: String) {
        downloadedModels.insert(modelName)
        
        // If this is the first downloaded model and no model is selected, select it
        if selectedModel == nil {
            selectedModel = modelName
        }
        
        // Also mark in persistent storage
        if let model = ModelData.availableModels.first(where: { $0.name == modelName }) {
            WhisperModelManager.shared.markModelAsDownloaded(model.whisperKitModelName)
        }
    }
    
    func getModelPath(for whisperKitModelName: String) -> URL {
        // Use the same path structure as WhisperKit
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath
            .appendingPathComponent("huggingface")
            .appendingPathComponent("models")
            .appendingPathComponent("argmaxinc")
            .appendingPathComponent("whisperkit-coreml")
            .appendingPathComponent(whisperKitModelName)
    }
}