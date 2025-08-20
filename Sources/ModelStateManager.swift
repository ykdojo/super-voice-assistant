import Foundation
import SwiftUI
import WhisperKit
import SharedModels

@MainActor
class ModelStateManager: ObservableObject {
    static let shared = ModelStateManager()
    
    enum ModelLoadingState: Equatable {
        case notDownloaded
        case downloading(progress: Double)
        case validating
        case downloaded
        case loading
        case loaded
    }
    
    @Published var downloadedModels: Set<String> = []
    @Published var isCheckingModels = true  // Start as true to prevent flash
    @Published var selectedModel: String? = nil {
        didSet {
            // Persist the selected model to UserDefaults
            if let model = selectedModel {
                UserDefaults.standard.set(model, forKey: "selectedWhisperModel")
            } else {
                UserDefaults.standard.removeObject(forKey: "selectedWhisperModel")
            }
        }
    }
    @Published var modelLoadingStates: [String: ModelLoadingState] = [:]
    @Published var loadedWhisperKit: WhisperKit? = nil
    private var currentLoadingTask: Task<WhisperKit?, Never>? = nil
    
    private init() {
        // Restore the selected model from UserDefaults
        self.selectedModel = UserDefaults.standard.string(forKey: "selectedWhisperModel")
    }
    
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
            
            // Update loading states for downloaded models
            for model in ModelData.availableModels {
                if newDownloadedModels.contains(model.name) {
                    // Only set to downloaded if not already loaded
                    if modelLoadingStates[model.name] != .loaded {
                        setLoadingState(for: model.name, state: .downloaded)
                    }
                } else {
                    setLoadingState(for: model.name, state: .notDownloaded)
                }
            }
            
            // If no model is selected but we have downloaded models, select the first one
            // Or if the selected model is no longer available, select the first one
            if let selected = self.selectedModel, !newDownloadedModels.contains(selected) {
                // Previously selected model is no longer available
                self.selectedModel = newDownloadedModels.first
            } else if self.selectedModel == nil && !newDownloadedModels.isEmpty {
                self.selectedModel = newDownloadedModels.first
            }
            
            self.isCheckingModels = false
        }
    }
    
    func markModelAsDownloaded(_ modelName: String) {
        downloadedModels.insert(modelName)
        setLoadingState(for: modelName, state: .downloaded)
        
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
    
    func getLoadingState(for modelName: String) -> ModelLoadingState {
        if let state = modelLoadingStates[modelName] {
            return state
        }
        
        // Determine state based on what we know
        if downloadedModels.contains(modelName) {
            // Check if it's the currently loaded model
            if selectedModel == modelName && loadedWhisperKit != nil {
                return .loaded
            }
            return .downloaded
        }
        
        return .notDownloaded
    }
    
    func setLoadingState(for modelName: String, state: ModelLoadingState) {
        modelLoadingStates[modelName] = state
    }
    
    func loadModel(_ modelName: String) async -> WhisperKit? {
        // Cancel any existing loading task
        currentLoadingTask?.cancel()
        
        // Clear loading states for all models that were loading
        await MainActor.run {
            for model in ModelData.availableModels {
                if modelLoadingStates[model.name] == .loading {
                    setLoadingState(for: model.name, state: .downloaded)
                }
            }
        }
        
        // Create new loading task
        let task = Task { () -> WhisperKit? in
            guard let modelInfo = ModelData.availableModels.first(where: { $0.name == modelName }) else {
                print("Model info not found for: \(modelName)")
                return nil
            }
            
            let whisperKitModelName = modelInfo.whisperKitModelName
            let modelPath = getModelPath(for: whisperKitModelName)
            
            guard WhisperModelManager.shared.isModelDownloaded(whisperKitModelName) else {
                print("Model \(modelName) is not downloaded")
                return nil
            }
            
            // Check if cancelled before starting
            if Task.isCancelled {
                print("Model loading cancelled for: \(modelName)")
                return nil
            }
            
            // Update state to loading
            await MainActor.run {
                setLoadingState(for: modelName, state: .loading)
            }
            
            do {
                print("Loading WhisperKit with model: \(modelName)")
                let whisperKit = try await WhisperKit(
                    modelFolder: modelPath.path,
                    verbose: false,
                    logLevel: .error
                )
                
                // Check if cancelled after loading
                if Task.isCancelled {
                    print("Model loading cancelled after load for: \(modelName)")
                    await MainActor.run {
                        setLoadingState(for: modelName, state: .downloaded)
                    }
                    return nil
                }
                
                // Update state to loaded
                await MainActor.run {
                    self.loadedWhisperKit = whisperKit
                    setLoadingState(for: modelName, state: .loaded)
                    // Clear loading states for other models
                    for model in ModelData.availableModels where model.name != modelName {
                        if modelLoadingStates[model.name] == .loaded || modelLoadingStates[model.name] == .loading {
                            setLoadingState(for: model.name, state: .downloaded)
                        }
                    }
                }
                
                print("WhisperKit loaded successfully")
                return whisperKit
            } catch {
                // Check if error is due to cancellation
                if Task.isCancelled {
                    print("Model loading cancelled: \(modelName)")
                } else {
                    print("Failed to load WhisperKit: \(error)")
                }
                
                // Revert state to downloaded
                await MainActor.run {
                    setLoadingState(for: modelName, state: .downloaded)
                }
                
                return nil
            }
        }
        
        currentLoadingTask = task
        return await task.value
    }
}