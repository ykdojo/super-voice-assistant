import Cocoa
import SwiftUI
import WhisperKit
import Hub

@MainActor
struct SettingsView: View {
    @State private var selectedModel = "distil-large-v3"
    @State private var downloadingModels: Set<String> = []
    @State private var downloadProgress: [String: Double] = [:]
    @State private var downloadedModels: Set<String> = []
    @State private var downloadErrors: [String: String] = [:]
    
    let models = ModelData.availableModels
    
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
            
            // Model Selection
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(models, id: \.name) { model in
                        ModelCard(
                            model: model,
                            isSelected: selectedModel == model.name,
                            isDownloaded: checkIfModelDownloaded(model.name),
                            isDownloading: downloadingModels.contains(model.name),
                            downloadProgress: downloadProgress[model.name] ?? 0,
                            downloadError: downloadErrors[model.name],
                            onSelect: {
                                selectedModel = model.name
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
                Label("Current model: \(currentModelDisplay)", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Done") {
                    NSApplication.shared.keyWindow?.close()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 600, height: 500)
        .onAppear {
            Task {
                await checkDownloadedModels()
            }
        }
    }
    
    var currentModelDisplay: String {
        models.first(where: { $0.name == selectedModel })?.displayName ?? "None"
    }
    
    func checkIfModelDownloaded(_ modelName: String) -> Bool {
        return downloadedModels.contains(modelName)
    }
    
    func checkDownloadedModels() async {
        // Check which models are already downloaded by trying to load them
        var partiallyDownloadedModels: [String] = []
        
        for model in models {
            let modelPath = getModelPath(for: model.whisperKitModelName)
            
            // First check if directory exists
            if !FileManager.default.fileExists(atPath: modelPath.path) {
                continue
            }
            
            // Try to load the model with WhisperKit to validate it's complete
            do {
                let _ = try await WhisperKit(
                    modelFolder: modelPath.path,
                    verbose: false,
                    logLevel: .error,
                    load: true
                )
                
                // If loading succeeded, the model is complete
                downloadedModels.insert(model.name)
            } catch {
                // Model exists but is incomplete or corrupted - auto-resume download
                print("Model \(model.name) exists but is incomplete, auto-resuming download...")
                partiallyDownloadedModels.append(model.name)
            }
        }
        
        // Auto-resume downloads for partially downloaded models
        for modelName in partiallyDownloadedModels {
            await MainActor.run {
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
        guard let model = models.first(where: { $0.name == modelName }) else {
            print("Model not found: \(modelName)")
            return
        }
        
        print("Starting download of \(model.displayName)...")
        downloadingModels.insert(modelName)
        downloadProgress[modelName] = 0.0
        
        Task {
            do {
                // Perform the actual download with real progress tracking
                let _ = try await WhisperModelDownloader.downloadModel(
                    from: model,
                    progressCallback: { progress in
                        Task { @MainActor in
                            // Update progress based on actual download progress
                            downloadProgress[modelName] = progress.fractionCompleted
                            
                            // If download is complete
                            if progress.isFinished {
                                downloadProgress[modelName] = 1.0
                            }
                        }
                    }
                )
                
                // Validate the downloaded model
                let modelPath = getModelPath(for: model.whisperKitModelName)
                var isValidModel = false
                
                do {
                    let _ = try await WhisperKit(
                        modelFolder: modelPath.path,
                        verbose: false,
                        logLevel: .error,
                        load: true
                    )
                    isValidModel = true
                } catch {
                    print("Downloaded model failed validation: \(error)")
                }
                
                // Update UI on success
                await MainActor.run {
                    downloadProgress[modelName] = 1.0
                    if isValidModel {
                        downloadedModels.insert(modelName)
                    }
                    
                    // Clean up after a short delay to show 100%
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        downloadingModels.remove(modelName)
                        downloadProgress.removeValue(forKey: modelName)
                        
                        if !isValidModel {
                            downloadErrors[modelName] = "Model download incomplete. Please try again."
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
                }
            }
        }
    }
}

struct AccuracyBar: View {
    let accuracy: String
    let note: String
    let sourceURL: String
    
    var accuracyValue: Double {
        // Remove both tilde and percentage sign for parsing
        let cleanedAccuracy = accuracy
            .replacingOccurrences(of: "~", with: "")
            .replacingOccurrences(of: "%", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Double(cleanedAccuracy) ?? 0.0
    }
    
    var fillColor: Color {
        switch accuracyValue {
        case 97...:
            return .green
        case 95..<97:
            return .blue
        case 93..<95:
            return .orange
        default:
            return .yellow
        }
    }
    
    var body: some View {
        HStack(spacing: 6) {
            // Bar chart icon
            Image(systemName: "chart.bar.fill")
                .foregroundColor(.secondary)
                .font(.caption)
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(fillColor)
                        .frame(width: geometry.size.width * accuracyValue / 100, height: 8)
                }
            }
            .frame(width: 40, height: 8)
            
            Text(accuracy)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .frame(minWidth: 45, alignment: .leading)
                .fixedSize()
            
            // Info button for source
            Button(action: {
                if let url = URL(string: sourceURL) {
                    NSWorkspace.shared.open(url)
                }
            }) {
                Image(systemName: "info.circle")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("View benchmark source")
        }
        .help(note) // This adds the tooltip on hover
    }
}

struct ModelCard: View {
    let model: ModelInfo
    let isSelected: Bool
    let isDownloaded: Bool
    let isDownloading: Bool
    let downloadProgress: Double
    let downloadError: String?
    let onSelect: () -> Void
    let onDownload: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Radio button
            Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .imageScale(.large)
                .onTapGesture {
                    if isDownloaded {
                        onSelect()
                    }
                }
            
            // Model info
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(model.displayName)
                        .font(.headline)
                    
                    // Language badge
                    Text(model.languages)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.blue.opacity(0.15))
                        )
                        .foregroundColor(.blue)
                }
                
                Text(model.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "internaldrive")
                        Text(model.size)
                            .fixedSize()
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "speedometer")
                        Text(model.speed)
                            .fixedSize()
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .help("Speed relative to baseline. See https://huggingface.co/spaces/argmaxinc/whisperkit-benchmarks for detailed performance metrics.")
                    
                    AccuracyBar(accuracy: model.accuracy, note: model.accuracyNote, sourceURL: model.sourceURL)
                }
            }
            
            Spacer()
            
            // Download button or status
            if isDownloaded {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Downloaded")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if isDownloading {
                HStack(spacing: 8) {
                    ProgressView(value: downloadProgress)
                        .progressViewStyle(.linear)
                        .frame(width: 80)
                    Text(String(format: "%.1f%%", downloadProgress * 100))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 45)
                }
            } else {
                VStack(alignment: .trailing, spacing: 4) {
                    Button(action: onDownload) {
                        Label("Download", systemImage: "arrow.down.circle")
                    }
                    .buttonStyle(.bordered)
                    
                    if let error = downloadError {
                        Text(error)
                            .font(.caption2)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.gray.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.2), lineWidth: 1)
        )
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
        
        let hostingController = NSHostingController(rootView: SettingsView())
        window.contentViewController = hostingController
        
        self.init(window: window)
    }
    
    func showWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}