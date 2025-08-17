import Cocoa
import SwiftUI

struct ModelInfo {
    let name: String
    let displayName: String
    let size: String
    let speed: String
    let accuracy: String
    let accuracyNote: String
    let languages: String
    let description: String
    let sourceURL: String
}

struct SettingsView: View {
    @State private var selectedModel = "small.en"
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0.0
    
    let models = [
        ModelInfo(
            name: "small.en",
            displayName: "Small English",
            size: "244 MB",
            speed: "~30x RT",
            accuracy: "93%",
            accuracyNote: "~7% WER on LibriSpeech test-clean dataset",
            languages: "English only",
            description: "Fastest option, great for quick dictation",
            sourceURL: "https://github.com/openai/whisper#available-models-and-languages"
        ),
        ModelInfo(
            name: "medium.en",
            displayName: "Medium English",
            size: "769 MB",
            speed: "~12x RT",
            accuracy: "95%",
            accuracyNote: "~5% WER, 3x slower than small but more accurate",
            languages: "English only",
            description: "Better accuracy for longer or complex content",
            sourceURL: "https://github.com/openai/whisper#available-models-and-languages"
        ),
        ModelInfo(
            name: "distil-large-v3",
            displayName: "Distil Large v3",
            size: "756 MB",
            speed: "~25x RT",
            accuracy: "96%",
            accuracyNote: "Within 1% WER of Large v3, 6.3x faster (Hugging Face)",
            languages: "99 languages",
            description: "Best speed/accuracy balance, multilingual support",
            sourceURL: "https://huggingface.co/distil-whisper/distil-large-v3#evaluation"
        ),
        ModelInfo(
            name: "large-v3-turbo",
            displayName: "Large v3 Turbo",
            size: "809 MB",
            speed: "~8x RT",
            accuracy: "96%",
            accuracyNote: "~4% WER average across languages (OpenAI benchmarks)",
            languages: "99 languages",
            description: "Optimized decoder for faster multilingual transcription",
            sourceURL: "https://github.com/openai/whisper/discussions/2363"
        ),
        ModelInfo(
            name: "large-v3",
            displayName: "Large v3",
            size: "1.5 GB",
            speed: "~4x RT",
            accuracy: "97%",
            accuracyNote: "State-of-the-art: 10-20% lower WER than v2 (OpenAI)",
            languages: "99 languages",
            description: "Highest accuracy, best for professional transcription",
            sourceURL: "https://github.com/openai/whisper/discussions/1762"
        )
    ]
    
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
                            onSelect: {
                                selectedModel = model.name
                            },
                            onDownload: {
                                downloadModel(model.name)
                            }
                        )
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Footer with current status
            HStack {
                if isDownloading {
                    ProgressView(value: downloadProgress)
                        .progressViewStyle(.linear)
                        .frame(width: 200)
                    Text("Downloading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Label("Current model: \(currentModelDisplay)", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Done") {
                    NSApplication.shared.keyWindow?.close()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 600, height: 500)
    }
    
    var currentModelDisplay: String {
        models.first(where: { $0.name == selectedModel })?.displayName ?? "None"
    }
    
    func checkIfModelDownloaded(_ modelName: String) -> Bool {
        // Mock implementation - returns true for small.en model
        return modelName == "small.en"
    }
    
    func downloadModel(_ modelName: String) {
        print("Downloading model: \(modelName)")
        isDownloading = true
        downloadProgress = 0.0
        
        // Mock download progress
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            downloadProgress += 0.05
            if downloadProgress >= 1.0 {
                timer.invalidate()
                isDownloading = false
                downloadProgress = 0.0
            }
        }
    }
}

struct AccuracyBar: View {
    let accuracy: String
    let note: String
    let sourceURL: String
    
    var accuracyValue: Int {
        Int(accuracy.replacingOccurrences(of: "%", with: "")) ?? 0
    }
    
    var fillColor: Color {
        switch accuracyValue {
        case 96...:
            return .green
        case 94..<96:
            return .blue
        case 92..<94:
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
                        .frame(width: geometry.size.width * CGFloat(accuracyValue) / 100, height: 8)
                }
            }
            .frame(width: 40, height: 8)
            
            Text(accuracy)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .frame(minWidth: 32, alignment: .leading)
            
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
                    .help("RT = Real-Time. 30x RT means 30 seconds of audio processes in 1 second. Speeds vary by device.")
                    
                    AccuracyBar(accuracy: model.accuracy, note: model.accuracyNote, sourceURL: model.sourceURL)
                }
            }
            
            Spacer()
            
            // Download button or status
            if isDownloaded {
                Text("Downloaded")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Button(action: onDownload) {
                    Label("Download", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.bordered)
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