import Cocoa
import SwiftUI
import KeyboardShortcuts
import AVFoundation
import WhisperKit
import SharedModels
import Combine

extension KeyboardShortcuts.Name {
    static let startRecording = Self("startRecording")
    static let insertPlaceholder = Self("insertPlaceholder")
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var isRecording = false
    var settingsWindow: SettingsWindowController?
    
    private var audioEngine: AVAudioEngine!
    private var inputNode: AVAudioInputNode!
    private var audioBuffer: [Float] = []
    private var displayTimer: Timer?
    private let sampleRate: Double = 16000
    private var modelCancellable: AnyCancellable?
    
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
        menu.addItem(NSMenuItem(title: "Insert Text: Press Shift+Alt+A", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        
        // Set default keyboard shortcut (Shift+Alt+Z)
        KeyboardShortcuts.setShortcut(.init(.z, modifiers: [.shift, .option]), for: .startRecording)
        
        // Set default keyboard shortcut for placeholder text (Shift+Alt+A)
        KeyboardShortcuts.setShortcut(.init(.a, modifiers: [.shift, .option]), for: .insertPlaceholder)
        
        // Set up keyboard shortcut handler
        KeyboardShortcuts.onKeyUp(for: .startRecording) { [weak self] in
            self?.toggleRecording()
        }
        
        // Set up placeholder text shortcut handler
        KeyboardShortcuts.onKeyUp(for: .insertPlaceholder) { [weak self] in
            self?.insertPlaceholderText()
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
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Voice Assistant")
            button.title = ""
        }
        
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
    
    @MainActor
    func processRecording() async {
        guard !audioBuffer.isEmpty else {
            print("No audio recorded")
            return
        }
        
        // Load model if not already loaded
        if ModelStateManager.shared.loadedWhisperKit == nil {
            if let selectedModel = ModelStateManager.shared.selectedModel {
                _ = await ModelStateManager.shared.loadModel(selectedModel)
            }
        }
        
        guard let whisperKit = ModelStateManager.shared.loadedWhisperKit else {
            print("WhisperKit not initialized - please select and download a model in Settings")
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
                    
                    // Copy to clipboard
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(transcription, forType: .string)
                    
                    // Show notification
                    showTranscriptionNotification(transcription)
                } else {
                    print("No transcription generated (possibly silence)")
                }
            }
        } catch {
            print("Transcription error: \(error)")
            showTranscriptionError("Transcription failed: \(error.localizedDescription)")
        }
    }
    
    func showTranscriptionNotification(_ text: String) {
        let notification = NSUserNotification()
        notification.title = "Transcription Complete"
        notification.informativeText = text
        notification.subtitle = "Copied to clipboard"
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
    
    func insertPlaceholderText() {
        let placeholderText = "Lorem ipsum dolor sit amet, consectetur adipiscing elit."
        
        // Save current clipboard contents
        let pasteboard = NSPasteboard.general
        let savedTypes = pasteboard.types ?? []
        var savedItems: [NSPasteboard.PasteboardType: Data] = [:]
        
        // Save all data from the clipboard
        for type in savedTypes {
            if let data = pasteboard.data(forType: type) {
                savedItems[type] = data
            }
        }
        
        print("📋 Saved \(savedItems.count) clipboard types")
        
        // Clear clipboard and set our placeholder text
        pasteboard.clearContents()
        pasteboard.setString(placeholderText, forType: .string)
        
        // Simulate Cmd+V to paste
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Key down for Cmd+V
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) { // 0x09 is 'V' key
            keyDown.flags = .maskCommand
            keyDown.post(tap: .cghidEventTap)
        }
        
        // Key up for V (no command flag on key up!)
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) {
            // Don't set command flag on key up - just release the V key
            keyUp.post(tap: .cghidEventTap)
        }
        
        print("✅ Pasted placeholder text")
        
        // Restore original clipboard contents after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            pasteboard.clearContents()
            
            // Restore all saved types
            for (type, data) in savedItems {
                pasteboard.setData(data, forType: type)
            }
            
            print("♻️ Restored \(savedItems.count) clipboard types")
        }
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
