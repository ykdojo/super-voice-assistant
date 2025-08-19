import Cocoa
import SwiftUI
import KeyboardShortcuts
import AVFoundation
import WhisperKit
import SharedModels
import Combine

extension KeyboardShortcuts.Name {
    static let startRecording = Self("startRecording")
    static let showHistory = Self("showHistory")
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var isRecording = false
    var settingsWindow: SettingsWindowController?
    private var copyFallbackWindow: CopyFallbackWindow?
    private var historyWindow: TranscriptionHistoryWindow?
    
    private var audioEngine: AVAudioEngine!
    private var inputNode: AVAudioInputNode!
    private var audioBuffer: [Float] = []
    private var displayTimer: Timer?
    private let sampleRate: Double = 16000
    private var modelCancellable: AnyCancellable?
    private var isTranscribing = false
    private var transcriptionTimer: Timer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Set the waveform icon
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Voice Assistant")
        }
        
        // Create menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Recording: Press Shift+Alt+Z", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "History: Press Shift+Alt+A", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "View History...", action: #selector(showTranscriptionHistory), keyEquivalent: "h"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        
        // Set default keyboard shortcuts
        KeyboardShortcuts.setShortcut(.init(.z, modifiers: [.shift, .option]), for: .startRecording)
        KeyboardShortcuts.setShortcut(.init(.a, modifiers: [.shift, .option]), for: .showHistory)
        
        // Set up keyboard shortcut handlers
        KeyboardShortcuts.onKeyUp(for: .startRecording) { [weak self] in
            self?.toggleRecording()
        }
        
        KeyboardShortcuts.onKeyUp(for: .showHistory) { [weak self] in
            self?.showTranscriptionHistory()
        }
        
        // Set up audio engine
        setupAudioEngine()
        
        // Request microphone permission
        requestMicrophonePermission()
        
        // Check downloaded models at startup (in background)
        Task {
            await ModelStateManager.shared.checkDownloadedModels()
            print("Model check completed at startup")
            
            // Load the initially selected model
            if let selectedModel = ModelStateManager.shared.selectedModel {
                _ = await ModelStateManager.shared.loadModel(selectedModel)
            }
        }
        
        // Observe model selection changes
        modelCancellable = ModelStateManager.shared.$selectedModel
            .dropFirst() // Skip the initial value
            .sink { selectedModel in
                guard let selectedModel = selectedModel else { return }
                Task {
                    // Load the new model
                    _ = await ModelStateManager.shared.loadModel(selectedModel)
                }
            }
    }
    
    func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        inputNode = audioEngine.inputNode
    }
    
    func requestMicrophonePermission() {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            if granted {
                print("Microphone permission granted")
            } else {
                print("Microphone permission denied")
                DispatchQueue.main.async {
                    self?.showPermissionAlert()
                }
            }
        }
    }
    
    func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Microphone Permission Required"
        alert.informativeText = "Please grant microphone access in System Settings > Privacy & Security > Microphone"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc func openSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController()
        }
        settingsWindow?.showWindow()
    }
    
    @objc func showTranscriptionHistory() {
        if historyWindow == nil {
            historyWindow = TranscriptionHistoryWindow()
        }
        historyWindow?.show()
    }
    
    func toggleRecording() {
        isRecording.toggle()
        
        if isRecording {
            startRecording()
        } else {
            stopRecording()
        }
    }
    
    func startRecording() {
        audioBuffer.removeAll()
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            
            let channelData = buffer.floatChannelData?[0]
            let frameLength = Int(buffer.frameLength)
            let inputSampleRate = buffer.format.sampleRate
            
            if let channelData = channelData {
                // Collect raw samples
                let samples = Array(UnsafeBufferPointer(start: channelData, count: frameLength))
                
                // Resample to 16kHz if needed for WhisperKit
                if inputSampleRate != self.sampleRate {
                    let ratio = Int(inputSampleRate / self.sampleRate)
                    let resampledSamples = stride(from: 0, to: samples.count, by: ratio).map { samples[$0] }
                    self.audioBuffer.append(contentsOf: resampledSamples)
                } else {
                    self.audioBuffer.append(contentsOf: samples)
                }
                
                
                let rms = sqrt(channelData.withMemoryRebound(to: Float.self, capacity: frameLength) { ptr in
                    var sum: Float = 0
                    for i in 0..<frameLength {
                        sum += ptr[i] * ptr[i]
                    }
                    return sum / Float(frameLength)
                })
                
                let db = 20 * log10(max(rms, 0.00001))
                
                DispatchQueue.main.async {
                    self.updateStatusBarWithLevel(db: db)
                }
            }
        }
        
        do {
            try audioEngine.start()
            print("🎤 Recording started...")
            
            displayTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                if self?.isRecording == false {
                    self?.displayTimer?.invalidate()
                }
            }
        } catch {
            print("Failed to start audio engine: \(error)")
            isRecording = false
        }
    }
    
    func stopRecording() {
        audioEngine.stop()
        inputNode.removeTap(onBus: 0)
        displayTimer?.invalidate()
        
        // Don't reset the icon here - let processRecording handle the transition
        
        print("⏹ Recording stopped")
        print("Captured \(audioBuffer.count) audio samples")
        
        // Process the recording
        Task {
            await processRecording()
        }
    }
    
    func updateStatusBarWithLevel(db: Float) {
        if let button = statusItem.button {
            button.image = nil
            
            // Convert dB to a 0-1 range (assuming -50dB to -20dB for normal speech)
            let normalizedLevel = max(0, min(1, (db + 50) / 30))
            
            // Create a visual bar using Unicode block characters
            let barLength = 8
            let filledLength = Int(normalizedLevel * Float(barLength))
            
            var bar = ""
            for i in 0..<barLength {
                if i < filledLength {
                    bar += "█"
                } else {
                    bar += "▁"
                }
            }
            
            button.title = "● " + bar
        }
    }
    
    func startTranscriptionIndicator() {
        isTranscribing = true
        
        // Show initial indicator
        if let button = statusItem.button {
            button.image = nil
            button.title = "⚙️ Processing..."
        }
        
        // Animate the indicator
        var dotCount = 0
        transcriptionTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self, self.isTranscribing else {
                self?.transcriptionTimer?.invalidate()
                return
            }
            
            if let button = self.statusItem.button {
                dotCount = (dotCount + 1) % 4
                let dots = String(repeating: ".", count: dotCount)
                let spaces = String(repeating: " ", count: 3 - dotCount)
                button.title = "⚙️ Processing" + dots + spaces
            }
        }
    }
    
    func stopTranscriptionIndicator() {
        isTranscribing = false
        transcriptionTimer?.invalidate()
        transcriptionTimer = nil
        
        // Reset to default icon
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Voice Assistant")
            button.title = ""
        }
    }
    
    @MainActor
    func processRecording() async {
        guard !audioBuffer.isEmpty else {
            print("No audio recorded")
            // Reset icon since we're not processing
            if let button = statusItem.button {
                button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Voice Assistant")
                button.title = ""
            }
            return
        }
        
        // Calculate RMS (Root Mean Square) to detect silence
        let rms = sqrt(audioBuffer.reduce(0) { $0 + $1 * $1 } / Float(audioBuffer.count))
        let db = 20 * log10(max(rms, 0.00001))
        
        // Threshold for silence detection (conservative: -50dB to avoid false positives)
        let silenceThreshold: Float = -50.0
        
        if db < silenceThreshold {
            print("Audio too quiet (RMS: \(rms), dB: \(db)). Skipping transcription.")
            // Reset icon since we're not processing
            if let button = statusItem.button {
                button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Voice Assistant")
                button.title = ""
            }
            return
        }
        
        // Start transcription indicator
        startTranscriptionIndicator()
        
        // Load model if not already loaded
        if ModelStateManager.shared.loadedWhisperKit == nil {
            if let selectedModel = ModelStateManager.shared.selectedModel {
                _ = await ModelStateManager.shared.loadModel(selectedModel)
            }
        }
        
        guard let whisperKit = ModelStateManager.shared.loadedWhisperKit else {
            print("WhisperKit not initialized - please select and download a model in Settings")
            stopTranscriptionIndicator()
            showTranscriptionError("No model loaded. Please select a model in Settings.")
            return
        }
        
        print("Transcribing \(audioBuffer.count) samples (\(Double(audioBuffer.count) / sampleRate) seconds)...")
        
        do {
            let transcriptionResult = try await whisperKit.transcribe(
                audioArray: audioBuffer,
                decodeOptions: DecodingOptions(
                    verbose: false,
                    task: .transcribe,
                    language: "en",
                    temperature: 0.0,
                    temperatureFallbackCount: 3,
                    sampleLength: 224,
                    topK: 5,
                    usePrefillPrompt: true,
                    usePrefillCache: true,
                    skipSpecialTokens: true,
                    withoutTimestamps: false,
                    clipTimestamps: [0],
                    suppressBlank: true,
                    supressTokens: nil
                )
            )
            
            if let firstResult = transcriptionResult.first {
                let transcription = firstResult.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                if !transcription.isEmpty {
                    print("✅ Transcription: \"\(transcription)\"")
                    
                    // Save to history
                    TranscriptionHistory.shared.addEntry(transcription)
                    
                    // Stop transcription indicator before pasting
                    stopTranscriptionIndicator()
                    
                    // Paste the transcription at cursor position
                    pasteTextAtCursor(transcription)
                    
                    // Show notification
                    showTranscriptionNotification(transcription)
                } else {
                    print("No transcription generated (possibly silence)")
                    stopTranscriptionIndicator()
                }
            } else {
                stopTranscriptionIndicator()
            }
        } catch {
            print("Transcription error: \(error)")
            stopTranscriptionIndicator()
            showTranscriptionError("Transcription failed: \(error.localizedDescription)")
        }
    }
    
    func showTranscriptionNotification(_ text: String) {
        let notification = NSUserNotification()
        notification.title = "Transcription Complete"
        notification.informativeText = text
        notification.subtitle = "Pasted at cursor"
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    func showTranscriptionError(_ message: String) {
        let notification = NSUserNotification()
        notification.title = "Transcription Error"
        notification.informativeText = message
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    func pasteTextAtCursor(_ text: String) {
        // Save current clipboard contents first
        let pasteboard = NSPasteboard.general
        let savedTypes = pasteboard.types ?? []
        var savedItems: [NSPasteboard.PasteboardType: Data] = [:]
        
        for type in savedTypes {
            if let data = pasteboard.data(forType: type) {
                savedItems[type] = data
            }
        }
        
        print("📋 Saved \(savedItems.count) clipboard types")
        
        // Set our text to clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Try to paste
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Create paste event
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) {
            keyDown.flags = .maskCommand
            keyDown.post(tap: .cghidEventTap)
        }
        
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) {
            keyUp.post(tap: .cghidEventTap)
        }
        
        print("✅ Paste command sent")
        
        // After a short delay, check if we should show fallback
        // The delay allows the paste to complete or fail
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            // Get the frontmost app to see where we tried to paste
            let frontmostApp = NSWorkspace.shared.frontmostApplication
            let appName = frontmostApp?.localizedName ?? "Unknown"
            let bundleId = frontmostApp?.bundleIdentifier ?? ""
            
            print("📱 Attempted paste in: \(appName) (\(bundleId))")
            
            // If we detect common scenarios where paste might fail, show fallback
            let problematicApps = [
                "com.apple.finder",
                "com.apple.dock", 
                "com.apple.systempreferences"
            ]
            
            // Check if the app is known to not accept pastes well
            // OR if the user is in an unusual context
            if problematicApps.contains(bundleId) {
                print("⚠️ Detected potential paste failure - showing fallback window")
                self?.showCopyFallbackWindow(text)
            }
            
            // Restore clipboard
            pasteboard.clearContents()
            for (type, data) in savedItems {
                pasteboard.setData(data, forType: type)
            }
            print("♻️ Restored clipboard")
        }
    }
    
    func showCopyFallbackWindow(_ text: String) {
        // Close any existing fallback window
        copyFallbackWindow?.close()
        
        // Create and show new window
        copyFallbackWindow = CopyFallbackWindow(text: text)
        copyFallbackWindow?.show()
    }
    
}

// Create and run the app
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular) // Show in dock and cmd+tab

// Set the app icon from our custom ICNS file
if let iconURL = Bundle.module.url(forResource: "AppIcon", withExtension: "icns"),
   let iconImage = NSImage(contentsOf: iconURL) {
    app.applicationIconImage = iconImage
}

app.run()
