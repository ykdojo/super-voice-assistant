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
    @State private var selectedModel = "distil-large-v3"
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0.0
    @State private var downloadingModel: String? = nil
    
    let models = [
        // Distil-Whisper Large v3
        // Primary Source: https://huggingface.co/distil-whisper/distil-large-v3
        // WhisperKit CoreML: https://huggingface.co/argmaxinc/whisperkit-coreml
        // Performance Citation: HuggingFace model card (accessed Jan 2025)
        // - 756M parameters, English-only specialization
        // - 6.3x faster than large-v3 (source: HF model card)
        // - 2.43% WER on LibriSpeech validation-clean
        // - Within 1.5% WER of large-v3 on short-form, within 1% on long-form
        ModelInfo(
            name: "distil-large-v3",
            displayName: "Distil Large v3",
            size: "756 MB",
            speed: "6.3x faster",
            accuracy: "97.6%",  // Calculated from 2.43% WER validation-clean
            accuracyNote: "English-only: 2.43% WER LibriSpeech validation-clean (HF model card Jan 2025)",
            languages: "English only",
            description: "Fastest high-accuracy option for English",
            sourceURL: "https://huggingface.co/distil-whisper/distil-large-v3"
        ),
        // Whisper Large v3 Turbo
        // Primary Source: https://huggingface.co/openai/whisper-large-v3-turbo
        // Release Announcement: https://github.com/openai/whisper/discussions/2363 (Oct 1, 2024)
        // WhisperKit Benchmarks: https://twitter.com/zachnagengast (Jan 2025)
        // - 809M parameters (source: HF model card)
        // - Reduced from 32 to 4 decoder layers for significant speed improvement
        // - WhisperKit: 107x real-time on M2 Ultra (processes 10 min audio in <6 seconds)
        // - Performs similarly to large-v2 across languages
        ModelInfo(
            name: "large-v3-turbo",
            displayName: "Large v3 Turbo",
            size: "809 MB",
            speed: "8x faster",
            accuracy: "~96%",  // Similar to large-v2 performance
            accuracyNote: "4 decoder layers, similar to large-v2 accuracy (OpenAI Oct 1, 2024)",
            languages: "99 languages",
            description: "Fast multilingual transcription with minimal accuracy loss",
            sourceURL: "https://huggingface.co/openai/whisper-large-v3-turbo"  // Official model card
        ),
        // Whisper Large v3
        // Primary Source: https://huggingface.co/openai/whisper-large-v3
        // Benchmark Citation: Aqua Voice Blog (Nov 2024): https://withaqua.com/blog/benchmark-nov-2024
        // GitHub announcement: https://github.com/openai/whisper/discussions/1762
        // - 1.54B parameters (source: HF model card)
        // - 1.80% WER on LibriSpeech test-clean (Aqua Voice benchmark Nov 2024)
        // - 10-20% error reduction vs v2 across all languages (OpenAI)
        // - Trained on 5M hours (1M weakly labeled + 4M pseudo-labeled)
        ModelInfo(
            name: "large-v3",
            displayName: "Large v3",
            size: "1.54 GB",
            speed: "Baseline",
            accuracy: "98.2%",  // Calculated from 1.80% WER on LibriSpeech test-clean
            accuracyNote: "State-of-the-art: 1.80% WER LibriSpeech test-clean (Aqua Voice Nov 2024)",
            languages: "99 languages",
            description: "Highest accuracy, best for professional transcription",
            sourceURL: "https://huggingface.co/openai/whisper-large-v3"  // Official model card
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
                            isDownloading: downloadingModel == model.name,
                            downloadProgress: downloadingModel == model.name ? downloadProgress : 0,
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
    }
    
    var currentModelDisplay: String {
        models.first(where: { $0.name == selectedModel })?.displayName ?? "None"
    }
    
    func checkIfModelDownloaded(_ modelName: String) -> Bool {
        // Mock implementation - returns true for distil-large-v3 model
        return modelName == "distil-large-v3"
    }
    
    func downloadModel(_ modelName: String) {
        print("Downloading model: \(modelName)")
        isDownloading = true
        downloadingModel = modelName
        downloadProgress = 0.0
        
        // Mock download progress
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            downloadProgress += 0.05
            if downloadProgress >= 1.0 {
                timer.invalidate()
                isDownloading = false
                downloadingModel = nil
                downloadProgress = 0.0
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
                    Text("\(Int(downloadProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 35)
                }
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