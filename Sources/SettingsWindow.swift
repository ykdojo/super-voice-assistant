import Cocoa
import SwiftUI
import WhisperKit
import Hub
import SharedModels

@MainActor
struct SettingsView: View {
    @StateObject private var modelState = ModelStateManager.shared
    @State private var downloadingModels: Set<String> = []
    @State private var downloadProgress: [String: Double] = [:]
    @State private var downloadErrors: [String: String] = [:]

    let whisperModels = ModelData.availableModels


    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Super Voice Assistant Settings")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Choose a speech recognition model")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()

            Divider()

            // All models in one list
            ScrollView {
                VStack(spacing: 12) {
                    // Parakeet section header
                    HStack {
                        Text("Parakeet")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("by FluidAudio")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 4)

                    // Parakeet models
                    ForEach(ParakeetVersion.allCases, id: \.self) { version in
                        ParakeetModelCard(
                            version: version,
                            isSelected: modelState.selectedEngine == .parakeet && modelState.parakeetVersion == version,
                            loadingState: parakeetLoadingState(for: version),
                            onSelect: {
                                modelState.selectedEngine = .parakeet
                                modelState.parakeetVersion = version
                                // Load the model if not already loaded
                                if modelState.parakeetLoadingState != .loaded {
                                    Task {
                                        await modelState.loadParakeetModel()
                                    }
                                }
                            },
                            onDownload: {
                                modelState.selectedEngine = .parakeet
                                modelState.parakeetVersion = version
                                Task {
                                    await modelState.loadParakeetModel()
                                }
                            }
                        )
                    }

                    // WhisperKit section header
                    HStack {
                        Text("WhisperKit")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("by Argmax")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 8)

                    // WhisperKit models
                    ForEach(whisperModels, id: \.name) { model in
                        ModelCard(
                            model: model,
                            isSelected: modelState.selectedEngine == .whisperKit && modelState.selectedModel == model.name,
                            isDownloaded: modelState.downloadedModels.contains(model.name),
                            isDownloading: downloadingModels.contains(model.name),
                            downloadProgress: downloadProgress[model.name] ?? 0,
                            downloadError: downloadErrors[model.name],
                            loadingState: modelState.getLoadingState(for: model.name),
                            onSelect: {
                                if modelState.downloadedModels.contains(model.name) {
                                    modelState.selectedEngine = .whisperKit
                                    modelState.selectedModel = model.name
                                }
                            },
                            onDownload: {
                                downloadModel(model.name)
                                downloadErrors.removeValue(forKey: model.name)
                            }
                        )
                    }
                }
                .padding()
            }

            Divider()

            // Footer with current status
            HStack {
                if modelState.isCheckingModels {
                    Label("Checking models...", systemImage: "arrow.clockwise")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    currentModelStatusLabel
                }

                Spacer()

                Button("Done") {
                    NSApplication.shared.keyWindow?.close()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 600, height: 550)
        .onAppear {
            // If models haven't been checked yet (e.g., settings opened very quickly after app start)
            if modelState.isCheckingModels {
                Task {
                    await modelState.checkDownloadedModels()
                }
            }

            // Check for incomplete downloads that need auto-resume
            Task {
                await checkForIncompleteDownloads()
            }
        }
    }

    @ViewBuilder
    private var currentModelStatusLabel: some View {
        switch modelState.selectedEngine {
        case .parakeet:
            switch modelState.parakeetLoadingState {
            case .loaded:
                Label("Current: \(modelState.parakeetVersion.displayName)", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            case .loading, .downloading:
                Label("Loading Parakeet...", systemImage: "arrow.clockwise")
                    .font(.caption)
                    .foregroundColor(.secondary)
            default:
                Label("Download a model to get started", systemImage: "arrow.down.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        case .whisperKit:
            if let selected = modelState.selectedModel,
               let model = whisperModels.first(where: { $0.name == selected }) {
                Label("Current: \(model.displayName)", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if modelState.downloadedModels.isEmpty {
                Label("Download a model to get started", systemImage: "arrow.down.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Label("Select a downloaded model", systemImage: "cursorarrow.click")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    /// Get loading state for a Parakeet version, checking filesystem for non-selected versions
    private func parakeetLoadingState(for version: ParakeetVersion) -> ParakeetLoadingState {
        // For the selected version when Parakeet is active, use the actual state
        if modelState.selectedEngine == .parakeet && modelState.parakeetVersion == version {
            return modelState.parakeetLoadingState
        }

        // For other versions or when WhisperKit is active, check if downloaded on disk
        let modelName = version == .v2 ? "parakeet-tdt-0.6b-v2-coreml" : "parakeet-tdt-0.6b-v3-coreml"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let modelPath = documentsPath.appendingPathComponent("FluidAudio").appendingPathComponent(modelName)

        if FileManager.default.fileExists(atPath: modelPath.path) {
            return .downloaded
        }
        return .notDownloaded
    }

    func checkForIncompleteDownloads() async {
        // Only check for incomplete downloads that need auto-resume
        var partiallyDownloadedModels: [String] = []
        
        for model in whisperModels {
            let modelPath = getModelPath(for: model.whisperKitModelName)
            
            // Check if directory exists but model is not in downloaded set
            if FileManager.default.fileExists(atPath: modelPath.path) && 
               !modelState.downloadedModels.contains(model.name) {
                // This model exists on disk but isn't marked as complete
                print("Model \(model.name) exists but is incomplete, will auto-resume download...")
                partiallyDownloadedModels.append(model.name)
            }
        }
        
        // Auto-resume downloads for partially downloaded models
        for modelName in partiallyDownloadedModels {
            await MainActor.run {
                // Just call downloadModel - it handles all the state setup
                downloadModel(modelName)
            }
        }
    }
    
    func getModelPath(for whisperKitModelName: String) -> URL {
        // Use the same path structure as WhisperKit/HubApi
        let hubApi = HubApi()
        let repo = Hub.Repo(id: "argmaxinc/whisperkit-coreml", type: .models)
        let repoLocation = hubApi.localRepoLocation(repo)
        return repoLocation.appendingPathComponent(whisperKitModelName)
    }
    
    func downloadModel(_ modelName: String) {
        guard let model = whisperModels.first(where: { $0.name == modelName }) else {
            print("Model not found: \(modelName)")
            return
        }

        // Prevent concurrent downloads of the same model
        guard !downloadingModels.contains(modelName) else {
            print("Model \(modelName) is already downloading, skipping...")
            return
        }

        print("Starting download of \(model.displayName)...")
        downloadingModels.insert(modelName)
        downloadProgress[modelName] = 0.0
        modelState.setLoadingState(for: modelName, state: .downloading(progress: 0.0))
        
        Task {
            do {
                // Perform the actual download with real progress tracking
                let _ = try await WhisperModelDownloader.downloadModel(
                    from: model,
                    progressCallback: { progress in
                        Task { @MainActor in
                            // Update progress based on actual download progress
                            downloadProgress[modelName] = progress.fractionCompleted
                            modelState.setLoadingState(for: modelName, state: .downloading(progress: progress.fractionCompleted))
                            
                            // If download is complete, show validating state
                            if progress.isFinished {
                                downloadProgress[modelName] = 1.0
                                modelState.setLoadingState(for: modelName, state: .validating)
                            }
                        }
                    }
                )
                
                // When download finishes, mark it as complete in our manager
                await MainActor.run {
                    modelState.markModelAsDownloaded(modelName)
                    
                    // Clean up after a short delay to show completion
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        downloadingModels.remove(modelName)
                        downloadProgress.removeValue(forKey: modelName)
                    }
                    
                    // Auto-load the model after download if it's the selected one
                    if modelState.selectedModel == modelName {
                        Task {
                            _ = await modelState.loadModel(modelName)
                        }
                    }
                }
                
                print("Successfully downloaded \(model.displayName)")
                
            } catch {
                print("Error downloading model: \(error)")
                await MainActor.run {
                    downloadErrors[modelName] = error.localizedDescription
                    downloadingModels.remove(modelName)
                    downloadProgress.removeValue(forKey: modelName)
                    modelState.setLoadingState(for: modelName, state: .notDownloaded)
                }
            }
        }
    }
}

class SettingsWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.center()
        window.isReleasedWhenClosed = false  // Prevent window from being released when closed
        
        let hostingController = NSHostingController(rootView: SettingsView())
        window.contentViewController = hostingController
        
        self.init(window: window)
    }
    
    func showWindow() {
        // Ensure window operations happen on main thread with proper timing
        DispatchQueue.main.async { [weak self] in
            self?.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}