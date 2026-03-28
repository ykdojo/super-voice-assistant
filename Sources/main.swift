import Cocoa
import SwiftUI
import KeyboardShortcuts
import AVFoundation
import WhisperKit
import SharedModels
import Combine
import ApplicationServices
import Foundation
import os.log

private let appLog = Logger(subsystem: "com.supervoiceassistant", category: "App")

// Environment variable loading
func loadEnvironmentVariables() {
    let fileManager = FileManager.default

    // Build list of candidate .env paths (first match wins)
    var candidates: [String] = []

    // 1. Current working directory (existing behavior, works for `swift run`)
    let cwd = fileManager.currentDirectoryPath
    candidates.append("\(cwd)/.env")

    // 2. Next to the .app bundle (e.g. ~/Applications/SuperVoiceAssistant.app/../.env)
    if let bundlePath = Bundle.main.bundlePath as String? {
        let bundleDir = (bundlePath as NSString).deletingLastPathComponent
        candidates.append("\(bundleDir)/.env")
    }

    // 3. XDG-style config directory
    let home = fileManager.homeDirectoryForCurrentUser.path
    candidates.append("\(home)/.config/supervoiceassistant/.env")

    // Try each candidate until we find one that exists
    guard let envPath = candidates.first(where: { fileManager.fileExists(atPath: $0) }),
          let envContent = try? String(contentsOfFile: envPath) else {
        print("⚠️ No .env file found. Searched: \(candidates.joined(separator: ", "))")
        appLog.warning("No .env file found. Searched: \(candidates.joined(separator: ", "), privacy: .public)")
        return
    }

    print("✅ Loaded .env from: \(envPath)")

    for line in envContent.components(separatedBy: .newlines) {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLine.isEmpty && !trimmedLine.hasPrefix("#") else { continue }

        let parts = trimmedLine.components(separatedBy: "=")
        guard parts.count >= 2 else { continue }

        let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        // Rejoin on "=" in case the value itself contains "="
        let value = parts.dropFirst().joined(separator: "=").trimmingCharacters(in: .whitespacesAndNewlines)
        setenv(key, value, 1)
    }
}

extension KeyboardShortcuts.Name {
    static let startRecording = Self("startRecording")
    static let showHistory = Self("showHistory")
    static let readSelectedText = Self("readSelectedText")
    static let toggleScreenRecording = Self("toggleScreenRecording")
    static let geminiAudioRecording = Self("geminiAudioRecording")
    static let pasteLastTranscription = Self("pasteLastTranscription")
}

class AppDelegate: NSObject, NSApplicationDelegate, AudioTranscriptionManagerDelegate, GeminiAudioRecordingManagerDelegate {
    var statusItem: NSStatusItem!
    var settingsWindow: SettingsWindowController?
    private var unifiedWindow: UnifiedManagerWindow?

    private var displayTimer: Timer?
    private var modelCancellable: AnyCancellable?
    private var engineCancellable: AnyCancellable?
    private var parakeetVersionCancellable: AnyCancellable?
    private var transcriptionTimer: Timer?
    private var videoProcessingTimer: Timer?
    private var audioManager: AudioTranscriptionManager!
    private var geminiAudioManager: GeminiAudioRecordingManager!
    private var streamingPlayer: GeminiStreamingPlayer?
    private var audioCollector: GeminiAudioCollector?
    private var isCurrentlyPlaying = false
    private var currentStreamingTask: Task<Void, Never>?
    private var screenRecorder = ScreenRecorder()
    private var currentVideoURL: URL?
    private var videoTranscriber = VideoTranscriber()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        appLog.info("SuperVoiceAssistant launching")
        // Load environment variables
        loadEnvironmentVariables()
        
        // Initialize streaming TTS components if API key is available
        if let apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !apiKey.isEmpty {
            if #available(macOS 14.0, *) {
                streamingPlayer = GeminiStreamingPlayer(playbackSpeed: 1.15)
                audioCollector = GeminiAudioCollector(apiKey: apiKey)
                print("✅ Streaming TTS components initialized")
            } else {
                print("⚠️ Streaming TTS requires macOS 14.0 or later")
            }
        } else {
            print("⚠️ GEMINI_API_KEY not found in environment variables")
            appLog.warning("GEMINI_API_KEY not found in environment variables")
        }
        
        // Create the status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Set the waveform icon
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Voice Assistant")
        }
        
        // Create menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Recording: Press Command+Option+Z", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Gemini Audio Recording: Press Command+Option+X", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "History: Press Command+Option+A", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Read Selected Text: Press Command+Option+S", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Screen Recording: Press Command+Option+C", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Paste Last Transcription: Press Command+Option+V", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "View History...", action: #selector(showTranscriptionHistory), keyEquivalent: "h"))
        menu.addItem(NSMenuItem(title: "Statistics...", action: #selector(showStats), keyEquivalent: "s"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        
        // Set default keyboard shortcuts
        KeyboardShortcuts.setShortcut(.init(.z, modifiers: [.command, .option]), for: .startRecording)
        KeyboardShortcuts.setShortcut(.init(.x, modifiers: [.command, .option]), for: .geminiAudioRecording)
        KeyboardShortcuts.setShortcut(.init(.a, modifiers: [.command, .option]), for: .showHistory)
        KeyboardShortcuts.setShortcut(.init(.s, modifiers: [.command, .option]), for: .readSelectedText)
        KeyboardShortcuts.setShortcut(.init(.c, modifiers: [.command, .option]), for: .toggleScreenRecording)
        KeyboardShortcuts.setShortcut(.init(.v, modifiers: [.command, .option]), for: .pasteLastTranscription)
        
        // Set up keyboard shortcut handlers
        KeyboardShortcuts.onKeyUp(for: .startRecording) { [weak self] in
            guard let self = self else { return }

            // Prevent starting audio recording if screen recording is active
            if self.screenRecorder.recording {
                let notification = NSUserNotification()
                notification.title = "Cannot Start Audio Recording"
                notification.informativeText = "Screen recording is currently active. Stop it first with Cmd+Option+C"
                NSUserNotificationCenter.default.deliver(notification)
                print("⚠️ Blocked audio recording - screen recording is active")
                return
            }

            // Prevent starting audio recording if Gemini audio recording is active
            if self.geminiAudioManager.isRecording {
                let notification = NSUserNotification()
                notification.title = "Cannot Start Audio Recording"
                notification.informativeText = "Gemini audio recording is currently active. Stop it first with Cmd+Option+X"
                NSUserNotificationCenter.default.deliver(notification)
                print("⚠️ Blocked audio recording - Gemini audio recording is active")
                return
            }

            // If about to start a fresh recording, make sure any previous
            // processing indicator is stopped and UI is reset.
            if !self.audioManager.isRecording {
                self.stopTranscriptionIndicator()
            }
            self.audioManager.toggleRecording()
        }
        
        KeyboardShortcuts.onKeyUp(for: .showHistory) { [weak self] in
            self?.showTranscriptionHistory()
        }
        
        KeyboardShortcuts.onKeyUp(for: .readSelectedText) { [weak self] in
            self?.handleReadSelectedTextToggle()
        }

        KeyboardShortcuts.onKeyUp(for: .geminiAudioRecording) { [weak self] in
            guard let self = self else { return }

            // Prevent starting Gemini audio recording if screen recording is active
            if self.screenRecorder.recording {
                let notification = NSUserNotification()
                notification.title = "Cannot Start Gemini Audio Recording"
                notification.informativeText = "Screen recording is currently active. Stop it first with Cmd+Option+C"
                NSUserNotificationCenter.default.deliver(notification)
                print("⚠️ Blocked Gemini audio recording - screen recording is active")
                return
            }

            // Prevent starting Gemini audio recording if WhisperKit recording is active
            if self.audioManager.isRecording {
                let notification = NSUserNotification()
                notification.title = "Cannot Start Gemini Audio Recording"
                notification.informativeText = "WhisperKit recording is currently active. Stop it first with Cmd+Option+Z"
                NSUserNotificationCenter.default.deliver(notification)
                print("⚠️ Blocked Gemini audio recording - WhisperKit recording is active")
                return
            }

            // If about to start a fresh recording, make sure any previous
            // processing indicator is stopped and UI is reset.
            if !self.geminiAudioManager.isRecording {
                self.stopTranscriptionIndicator()
            }
            self.geminiAudioManager.toggleRecording()
        }

        KeyboardShortcuts.onKeyUp(for: .toggleScreenRecording) { [weak self] in
            self?.toggleScreenRecording()
        }

        KeyboardShortcuts.onKeyUp(for: .pasteLastTranscription) { [weak self] in
            self?.pasteLastTranscription()
        }

        // Set up audio manager
        audioManager = AudioTranscriptionManager()
        audioManager.delegate = self

        // Set up Gemini audio manager
        geminiAudioManager = GeminiAudioRecordingManager()
        geminiAudioManager.delegate = self
        
        // Check downloaded models at startup (in background)
        Task {
            await ModelStateManager.shared.checkDownloadedModels()
            print("Model check completed at startup")

            // Load the initially selected model based on engine
            switch ModelStateManager.shared.selectedEngine {
            case .whisperKit:
                if let selectedModel = ModelStateManager.shared.selectedModel {
                    _ = await ModelStateManager.shared.loadModel(selectedModel)
                }
            case .parakeet:
                await ModelStateManager.shared.loadParakeetModel()
            }
        }

        // Observe WhisperKit model selection changes
        modelCancellable = ModelStateManager.shared.$selectedModel
            .dropFirst() // Skip the initial value
            .sink { selectedModel in
                guard let selectedModel = selectedModel else { return }
                // Only load if WhisperKit is the selected engine
                guard ModelStateManager.shared.selectedEngine == .whisperKit else { return }
                Task {
                    // Load the new model
                    _ = await ModelStateManager.shared.loadModel(selectedModel)
                }
            }

        // Observe engine changes - only handle memory management, not loading
        // Loading is triggered by user actions (selecting/downloading models)
        engineCancellable = ModelStateManager.shared.$selectedEngine
            .dropFirst() // Skip the initial value
            .sink { engine in
                switch engine {
                case .whisperKit:
                    // Unload Parakeet to free memory
                    ModelStateManager.shared.unloadParakeetModel()
                case .parakeet:
                    // Unload WhisperKit to free memory
                    ModelStateManager.shared.unloadWhisperKitModel()
                }
            }

        // Note: Parakeet version changes don't auto-load
        // User must click to download/select a specific version
    }
    

    
    @objc func openSettings() {
        if unifiedWindow == nil {
            unifiedWindow = UnifiedManagerWindow()
        }
        unifiedWindow?.showWindow(tab: .settings)
    }
    
    @objc func showTranscriptionHistory() {
        if unifiedWindow == nil {
            unifiedWindow = UnifiedManagerWindow()
        }
        unifiedWindow?.showWindow(tab: .history)
    }
    
    @objc func showStats() {
        if unifiedWindow == nil {
            unifiedWindow = UnifiedManagerWindow()
        }
        unifiedWindow?.showWindow(tab: .statistics)
    }
    
    func handleReadSelectedTextToggle() {
        // If currently playing, stop the audio
        if isCurrentlyPlaying {
            stopCurrentPlayback()
            return
        }

        // Otherwise, start reading selected text
        readSelectedText()
    }

    func toggleScreenRecording() {
        // Prevent starting screen recording if audio recording is active
        if !screenRecorder.recording && audioManager.isRecording {
            let notification = NSUserNotification()
            notification.title = "Cannot Start Screen Recording"
            notification.informativeText = "Audio recording is currently active. Stop it first with Cmd+Option+Z"
            NSUserNotificationCenter.default.deliver(notification)
            print("⚠️ Blocked screen recording - audio recording is active")
            return
        }

        // Prevent starting screen recording if Gemini audio recording is active
        if !screenRecorder.recording && geminiAudioManager.isRecording {
            let notification = NSUserNotification()
            notification.title = "Cannot Start Screen Recording"
            notification.informativeText = "Gemini audio recording is currently active. Stop it first with Cmd+Option+X"
            NSUserNotificationCenter.default.deliver(notification)
            print("⚠️ Blocked screen recording - Gemini audio recording is active")
            return
        }

        if screenRecorder.recording {
            // Stop recording
            screenRecorder.stopRecording { [weak self] result in
                guard let self = self else { return }

                switch result {
                case .success(let videoURL):
                    self.currentVideoURL = videoURL

                    // Start video processing indicator
                    self.startVideoProcessingIndicator()

                    // Transcribe the video
                    print("🎬 Starting transcription for: \(videoURL.lastPathComponent)")
                    self.videoTranscriber.transcribe(videoURL: videoURL) { result in
                        DispatchQueue.main.async {
                            self.stopVideoProcessingIndicator()

                            switch result {
                            case .success(var transcription):
                                // Apply text replacements from config
                                transcription = TextReplacements.shared.processText(transcription)

                                // Save to history
                                TranscriptionHistory.shared.addEntry(transcription)

                                // Paste transcription at cursor
                                self.pasteTextAtCursor(transcription)

                                // Delete the video file after successful transcription
                                if let videoURL = self.currentVideoURL {
                                    do {
                                        try FileManager.default.removeItem(at: videoURL)
                                        print("🗑️ Deleted video file: \(videoURL.lastPathComponent)")
                                    } catch {
                                        print("⚠️ Failed to delete video file: \(error.localizedDescription)")
                                    }
                                }

                                // Show completion notification with transcription
                                let completionNotification = NSUserNotification()
                                completionNotification.title = "Video Transcribed"
                                completionNotification.informativeText = transcription.prefix(100) + (transcription.count > 100 ? "..." : "")
                                completionNotification.subtitle = "Pasted at cursor"
                                NSUserNotificationCenter.default.deliver(completionNotification)

                                print("✅ Transcription complete:")
                                print("─────────────────")
                                print(transcription)
                                print("─────────────────")

                            case .failure(let error):
                                // Show error notification
                                let errorNotification = NSUserNotification()
                                errorNotification.title = "Transcription Failed"
                                errorNotification.informativeText = error.localizedDescription
                                NSUserNotificationCenter.default.deliver(errorNotification)

                                print("❌ Transcription failed: \(error.localizedDescription)")
                                appLog.error("Video transcription failed: \(error.localizedDescription, privacy: .public)")
                            }
                        }
                    }

                case .failure(let error):
                    print("❌ Screen recording failed: \(error.localizedDescription)")
                    appLog.error("Screen recording failed: \(error.localizedDescription, privacy: .public)")

                    let errorNotification = NSUserNotification()
                    errorNotification.title = "Recording Failed"
                    errorNotification.informativeText = error.localizedDescription
                    NSUserNotificationCenter.default.deliver(errorNotification)

                    // Reset status bar
                    if let button = self.statusItem.button {
                        button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Voice Assistant")
                        button.title = ""
                    }
                }
            }

            // Show stopping notification
            let notification = NSUserNotification()
            notification.title = "Screen Recording Stopped"
            notification.informativeText = "Saving video..."
            NSUserNotificationCenter.default.deliver(notification)
            print("⏹️ Screen recording STOPPED")

        } else {
            // Start recording
            screenRecorder.startRecording { [weak self] result in
                guard let self = self else { return }

                switch result {
                case .success(let videoURL):
                    self.currentVideoURL = videoURL

                    // Update status bar to show recording indicator
                    if let button = self.statusItem.button {
                        button.image = nil
                        button.title = "🎥 REC"
                    }

                    // Show success notification
                    let notification = NSUserNotification()
                    notification.title = "Screen Recording Started"
                    notification.informativeText = "Press Cmd+Option+C again to stop"
                    NSUserNotificationCenter.default.deliver(notification)
                    print("🎥 Screen recording STARTED")

                case .failure(let error):
                    print("❌ Failed to start recording: \(error.localizedDescription)")
                    appLog.error("Failed to start screen recording: \(error.localizedDescription, privacy: .public)")

                    let errorNotification = NSUserNotification()
                    errorNotification.title = "Recording Failed"
                    errorNotification.informativeText = error.localizedDescription
                    NSUserNotificationCenter.default.deliver(errorNotification)
                }
            }
        }
    }

    func pasteLastTranscription() {
        // Get the most recent transcription from history
        guard let lastEntry = TranscriptionHistory.shared.getEntries().first else {
            let notification = NSUserNotification()
            notification.title = "No Transcription Available"
            notification.informativeText = "No transcription history found"
            NSUserNotificationCenter.default.deliver(notification)
            print("⚠️ No transcription history to paste")
            return
        }

        // Paste the last transcription at cursor
        pasteTextAtCursor(lastEntry.text)

        let notification = NSUserNotification()
        notification.title = "Pasted Last Transcription"
        notification.informativeText = lastEntry.text.prefix(100) + (lastEntry.text.count > 100 ? "..." : "")
        NSUserNotificationCenter.default.deliver(notification)
        print("📋 Pasted last transcription: \(lastEntry.text.prefix(50))...")
    }

    func stopCurrentPlayback() {
        print("🛑 Stopping audio playback")
        
        // Cancel the current streaming task
        currentStreamingTask?.cancel()
        currentStreamingTask = nil
        
        // Stop the audio player
        streamingPlayer?.stopAudioEngine()
        
        // Reset playing state
        isCurrentlyPlaying = false
        
        let notification = NSUserNotification()
        notification.title = "Audio Stopped"
        notification.informativeText = "Text-to-speech playback stopped"
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    func readSelectedText() {
        // Save current clipboard contents first
        let pasteboard = NSPasteboard.general
        let savedTypes = pasteboard.types ?? []
        var savedItems: [NSPasteboard.PasteboardType: Data] = [:]
        
        for type in savedTypes {
            if let data = pasteboard.data(forType: type) {
                savedItems[type] = data
            }
        }
        
        print("📋 Saved \(savedItems.count) clipboard types before reading selection")
        
        // Simulate Cmd+C to copy selected text
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDownC = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true) // 'c' key
        let keyUpC = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        
        // Set Cmd modifier
        keyDownC?.flags = .maskCommand
        keyUpC?.flags = .maskCommand
        
        // Post the events
        keyDownC?.post(tap: .cghidEventTap)
        keyUpC?.post(tap: .cghidEventTap)
        
        // Give system a moment to process the copy command
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            // Read from clipboard
            let copiedText = pasteboard.string(forType: .string) ?? ""
            
            if !copiedText.isEmpty {
                print("📖 Selected text for streaming TTS: \(copiedText)")
                
                // Try to stream speech with our streaming components
                if let audioCollector = self?.audioCollector, let streamingPlayer = self?.streamingPlayer {
                    self?.isCurrentlyPlaying = true
                    
                    self?.currentStreamingTask = Task {
                        do {
                            let notification = NSUserNotification()
                            notification.title = "Streaming TTS"
                            notification.informativeText = "Starting streaming synthesis: \(copiedText.prefix(50))\(copiedText.count > 50 ? "..." : "")"
                            NSUserNotificationCenter.default.deliver(notification)
                            
                            // Stream audio using single API call for all text at once
                            try await streamingPlayer.playText(copiedText, audioCollector: audioCollector)
                            
                            // Check if task was cancelled
                            if Task.isCancelled {
                                return
                            }
                            
                            let completionNotification = NSUserNotification()
                            completionNotification.title = "Streaming TTS Complete"
                            completionNotification.informativeText = "Finished streaming selected text"
                            NSUserNotificationCenter.default.deliver(completionNotification)
                            
                        } catch is CancellationError {
                            print("🛑 Audio streaming was cancelled")
                            appLog.info("TTS playback cancelled by user")
                        } catch {
                            print("❌ Streaming TTS Error: \(error)")
                            appLog.error("Streaming TTS failed: \(error.localizedDescription, privacy: .public) | Full: \(String(describing: error), privacy: .public)")
                            
                            let errorNotification = NSUserNotification()
                            errorNotification.title = "Streaming TTS Error"
                            errorNotification.informativeText = "Failed to stream text: \(error.localizedDescription)"
                            NSUserNotificationCenter.default.deliver(errorNotification)
                            
                            // Note: Text is already in clipboard from Cmd+C, no need to copy again
                            let fallbackNotification = NSUserNotification()
                            fallbackNotification.title = "Text Ready in Clipboard"
                            fallbackNotification.informativeText = "Streaming failed, selected text copied via Cmd+C"
                            NSUserNotificationCenter.default.deliver(fallbackNotification)
                        }
                        
                        // Reset playing state when task completes (normally or via cancellation)
                        DispatchQueue.main.async {
                            self?.isCurrentlyPlaying = false
                            self?.currentStreamingTask = nil
                        }
                        
                        // Restore original clipboard contents after streaming
                        DispatchQueue.main.async {
                            pasteboard.clearContents()
                            for (type, data) in savedItems {
                                pasteboard.setData(data, forType: type)
                            }
                            print("♻️ Restored original clipboard contents")
                        }
                    }
                } else {
                    let notification = NSUserNotification()
                    notification.title = "Selected Text Copied"
                    notification.informativeText = "Streaming TTS not available, text copied to clipboard: \(copiedText.prefix(100))\(copiedText.count > 100 ? "..." : "")"
                    NSUserNotificationCenter.default.deliver(notification)
                    
                    // Don't restore clipboard in this case since user might want the copied text
                }
            } else {
                print("⚠️ No text was copied - nothing selected or copy failed")
                
                let notification = NSUserNotification()
                notification.title = "No Text Selected"
                notification.informativeText = "Please select some text first before using TTS"
                NSUserNotificationCenter.default.deliver(notification)
                
                // Restore clipboard since copy attempt failed
                pasteboard.clearContents()
                for (type, data) in savedItems {
                    pasteboard.setData(data, forType: type)
                }
                print("♻️ Restored clipboard after failed copy")
            }
        }
    }
    
    func updateStatusBarWithLevel(db: Float) {
        // Don't update status bar if screen recording is active
        if screenRecorder.recording {
            return
        }

        if let button = statusItem.button {
            button.image = nil

            // Convert dB to a 0-1 range (assuming -55dB to -20dB for normal speech)
            let normalizedLevel = max(0, min(1, (db + 55) / 35))

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
        // Don't update status bar if screen recording is active
        if screenRecorder.recording {
            return
        }

        // Show initial indicator
        if let button = statusItem.button {
            button.image = nil
            button.title = "⚙️ Processing..."
        }

        // Animate the indicator
        var dotCount = 0
        transcriptionTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else {
                self?.transcriptionTimer?.invalidate()
                return
            }

            // Don't update if screen recording is active
            if self.screenRecorder.recording {
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
        transcriptionTimer?.invalidate()
        transcriptionTimer = nil

        // Don't update status bar if screen recording is active
        if screenRecorder.recording {
            return
        }

        // If not currently recording, reset to default icon.
        // When recording, the live level updates will take over UI shortly.
        if audioManager?.isRecording != true {
            if let button = statusItem.button {
                button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Voice Assistant")
                button.title = ""
            }
        }
    }

    func startVideoProcessingIndicator() {
        // Show initial indicator
        if let button = statusItem.button {
            button.image = nil
            button.title = "🎬 Processing..."
        }

        // Animate the indicator
        var dotCount = 0
        videoProcessingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else {
                self?.videoProcessingTimer?.invalidate()
                return
            }

            if let button = self.statusItem.button {
                dotCount = (dotCount + 1) % 4
                let dots = String(repeating: ".", count: dotCount)
                let spaces = String(repeating: " ", count: 3 - dotCount)
                button.title = "🎬 Processing" + dots + spaces
            }
        }
    }

    func stopVideoProcessingIndicator() {
        videoProcessingTimer?.invalidate()
        videoProcessingTimer = nil

        // Reset to default icon
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Voice Assistant")
            button.title = ""
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
        appLog.error("Transcription error: \(message, privacy: .public)")
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
        
        // After a short delay, check if paste might have failed
        // and show history window for easy manual copying
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            // Get the frontmost app to see where we tried to paste
            let frontmostApp = NSWorkspace.shared.frontmostApplication
            let appName = frontmostApp?.localizedName ?? "Unknown"
            let bundleId = frontmostApp?.bundleIdentifier ?? ""
            
            print("📱 Attempted paste in: \(appName) (\(bundleId))")
            
            // Apps where paste typically fails or doesn't make sense
            let problematicApps = [
                "com.apple.finder",
                "com.apple.dock", 
                "com.apple.systempreferences"
            ]
            
            // Check if the app is known to not accept pastes well
            // OR if the user is in an unusual context
            if problematicApps.contains(bundleId) {
                print("⚠️ Detected potential paste failure - showing history window")
                self?.showHistoryForPasteFailure()
            }
            
            // Restore clipboard
            pasteboard.clearContents()
            for (type, data) in savedItems {
                pasteboard.setData(data, forType: type)
            }
            print("♻️ Restored clipboard")
        }
    }
    
    func showHistoryForPasteFailure() {
        // When paste fails in certain apps, show the history window
        // by simulating the Command+Option+A keyboard shortcut
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Key code for 'A' is 0x00
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x00, keyDown: true) {
            keyDown.flags = [.maskCommand, .maskAlternate]
            keyDown.post(tap: .cghidEventTap)
        }
        
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x00, keyDown: false) {
            keyUp.flags = [.maskCommand, .maskAlternate]
            keyUp.post(tap: .cghidEventTap)
        }
        
        print("📚 Showing history window for paste failure recovery")
    }
    
    // MARK: - AudioTranscriptionManagerDelegate
    
    func audioLevelDidUpdate(db: Float) {
        updateStatusBarWithLevel(db: db)
    }
    
    func transcriptionDidStart() {
        startTranscriptionIndicator()
    }
    
    func transcriptionDidComplete(text: String) {
        stopTranscriptionIndicator()
        pasteTextAtCursor(text)
        showTranscriptionNotification(text)
    }
    
    func transcriptionDidFail(error: String) {
        stopTranscriptionIndicator()
        showTranscriptionError(error)
    }
    
    func recordingWasCancelled() {
        // Ensure any processing indicator is stopped
        stopTranscriptionIndicator()
        // Reset the status bar icon
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Voice Assistant")
            button.title = ""
        }
        
        // Show notification
        let notification = NSUserNotification()
        notification.title = "Recording Cancelled"
        notification.informativeText = "Recording was cancelled"
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    func recordingWasSkippedDueToSilence() {
        // Ensure any processing indicator is stopped
        stopTranscriptionIndicator()
        // Reset the status bar icon
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Voice Assistant")
            button.title = ""
        }
        
        // Optionally show a subtle notification
        let notification = NSUserNotification()
        notification.title = "Recording Skipped"
        notification.informativeText = "Audio was too quiet to transcribe"
        NSUserNotificationCenter.default.deliver(notification)
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
