import Foundation
import SwiftUI
import WhisperKit
import SharedModels

/// Transcription engine selection
public enum TranscriptionEngine: String, CaseIterable {
    case whisperKit = "whisperKit"
    case parakeet = "parakeet"

    public var displayName: String {
        switch self {
        case .whisperKit:
            return "WhisperKit"
        case .parakeet:
            return "Parakeet"
        }
    }

    public var description: String {
        switch self {
        case .whisperKit:
            return "On-device transcription by Argmax"
        case .parakeet:
            return "Fast & accurate by FluidAudio"
        }
    }
}

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

    // MARK: - Engine Selection
    @Published var selectedEngine: TranscriptionEngine = .whisperKit {
        didSet {
            UserDefaults.standard.set(selectedEngine.rawValue, forKey: "selectedTranscriptionEngine")
        }
    }

    // MARK: - Parakeet State
    @Published var loadedParakeetTranscriber: ParakeetTranscriber? = nil
    @Published var parakeetVersion: ParakeetVersion = .v2 {
        didSet {
            UserDefaults.standard.set(parakeetVersion.rawValue, forKey: "selectedParakeetVersion")
        }
    }
    @Published var parakeetLoadingState: ParakeetLoadingState = .notDownloaded
    private var currentParakeetLoadingTask: Task<Void, Never>? = nil

    // MARK: - WhisperKit State
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
        // Restore the selected engine from UserDefaults
        if let engineRaw = UserDefaults.standard.string(forKey: "selectedTranscriptionEngine"),
           let engine = TranscriptionEngine(rawValue: engineRaw) {
            self.selectedEngine = engine
        }

        // Restore the selected Parakeet version from UserDefaults
        if let versionRaw = UserDefaults.standard.string(forKey: "selectedParakeetVersion"),
           let version = ParakeetVersion(rawValue: versionRaw) {
            self.parakeetVersion = version
        }

        // Restore the selected WhisperKit model from UserDefaults
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
        // First check if this model is actually loaded in memory
        if selectedModel == modelName && loadedWhisperKit != nil {
            return .loaded
        }

        // Check for in-progress states (downloading, loading, validating)
        if let state = modelLoadingStates[modelName] {
            switch state {
            case .downloading, .loading, .validating:
                return state
            case .loaded:
                // Only return loaded if WhisperKit is actually loaded (checked above)
                return .downloaded
            case .downloaded, .notDownloaded:
                break
            }
        }

        // Determine state based on download status
        if downloadedModels.contains(modelName) {
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

    // MARK: - Parakeet Model Loading

    func loadParakeetModel() async {
        // Skip if already downloading or loading
        guard parakeetLoadingState != .downloading && parakeetLoadingState != .loading else {
            print("Parakeet model already downloading/loading, skipping...")
            return
        }

        // Cancel any existing loading task (shouldn't happen with guard above, but just in case)
        currentParakeetLoadingTask?.cancel()

        // Check if model is already cached - show "loading" vs "downloading"
        let modelName = parakeetVersion == .v2 ? "parakeet-tdt-0.6b-v2-coreml" : "parakeet-tdt-0.6b-v3-coreml"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let modelPath = documentsPath.appendingPathComponent("FluidAudio").appendingPathComponent(modelName)
        let isAlreadyDownloaded = FileManager.default.fileExists(atPath: modelPath.path)

        // Set appropriate state
        parakeetLoadingState = isAlreadyDownloaded ? .loading : .downloading

        // Create new loading task
        let task = Task { () -> Void in
            // Check if cancelled before starting
            if Task.isCancelled {
                print("Parakeet model loading cancelled")
                return
            }

            do {
                let transcriber = ParakeetTranscriber()
                try await transcriber.loadModel(version: parakeetVersion)

                // Check if cancelled after loading
                if Task.isCancelled {
                    print("Parakeet model loading cancelled after load")
                    await MainActor.run {
                        parakeetLoadingState = .notDownloaded
                    }
                    return
                }

                // Update state to loaded
                await MainActor.run {
                    self.loadedParakeetTranscriber = transcriber
                    self.parakeetLoadingState = .loaded
                }

                print("Parakeet model loaded successfully: \(parakeetVersion.displayName)")

            } catch {
                if Task.isCancelled {
                    print("Parakeet model loading cancelled: \(error)")
                } else {
                    print("Failed to load Parakeet model: \(error)")
                }

                await MainActor.run {
                    parakeetLoadingState = .notDownloaded
                    loadedParakeetTranscriber = nil
                }
            }
        }

        currentParakeetLoadingTask = task
        await task.value
    }

    /// Unload Parakeet model to free memory
    func unloadParakeetModel() {
        loadedParakeetTranscriber?.unloadModel()
        loadedParakeetTranscriber = nil

        // Check if model files exist on disk before setting state
        let modelName = parakeetVersion == .v2 ? "parakeet-tdt-0.6b-v2-coreml" : "parakeet-tdt-0.6b-v3-coreml"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let modelPath = documentsPath.appendingPathComponent("FluidAudio").appendingPathComponent(modelName)

        if FileManager.default.fileExists(atPath: modelPath.path) {
            parakeetLoadingState = .downloaded
        } else {
            parakeetLoadingState = .notDownloaded
        }
        print("Parakeet model unloaded")
    }

    /// Unload WhisperKit model to free memory
    func unloadWhisperKitModel() {
        loadedWhisperKit = nil
        // Reset loading states to downloaded for all downloaded models
        for model in ModelData.availableModels where downloadedModels.contains(model.name) {
            setLoadingState(for: model.name, state: .downloaded)
        }
        print("WhisperKit model unloaded")
    }
}