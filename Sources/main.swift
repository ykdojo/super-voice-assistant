import Cocoa
import SwiftUI
import KeyboardShortcuts
import AVFoundation
import WhisperKit
import SharedModels
import Combine
import ApplicationServices
import Foundation

// Environment variable loading
func loadEnvironmentVariables() {
    let fileManager = FileManager.default
    let currentDirectory = fileManager.currentDirectoryPath
    let envPath = "\(currentDirectory)/.env"
    
    guard fileManager.fileExists(atPath: envPath),
          let envContent = try? String(contentsOfFile: envPath) else {
        return
    }
    
    for line in envContent.components(separatedBy: .newlines) {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLine.isEmpty && !trimmedLine.hasPrefix("#") else { continue }
        
        let parts = trimmedLine.components(separatedBy: "=")
        guard parts.count == 2 else { continue }
        
        let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        setenv(key, value, 1)
    }
}

extension KeyboardShortcuts.Name {
    static let startRecording = Self("startRecording")
    static let showHistory = Self("showHistory")
    static let readSelectedText = Self("readSelectedText")
    static let takeScreenshot = Self("takeScreenshot")
}

class AppDelegate: NSObject, NSApplicationDelegate, AudioTranscriptionManagerDelegate {
    var statusItem: NSStatusItem!
    var settingsWindow: SettingsWindowController?
    private var unifiedWindow: UnifiedManagerWindow?
    
    private var displayTimer: Timer?
    private var modelCancellable: AnyCancellable?
    private var transcriptionTimer: Timer?
    private var audioManager: AudioTranscriptionManager!
    private var streamingPlayer: GeminiStreamingPlayer?
    private var audioCollector: GeminiAudioCollector?
    private var isCurrentlyPlaying = false
    private var currentStreamingTask: Task<Void, Never>?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
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
        menu.addItem(NSMenuItem(title: "History: Press Command+Option+A", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Read Selected Text: Press Command+Option+S", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Take Screenshot: Press Command+Option+X", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "View History...", action: #selector(showTranscriptionHistory), keyEquivalent: "h"))
        menu.addItem(NSMenuItem(title: "Statistics...", action: #selector(showStats), keyEquivalent: "s"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        
        // Set default keyboard shortcuts
        KeyboardShortcuts.setShortcut(.init(.z, modifiers: [.command, .option]), for: .startRecording)
        KeyboardShortcuts.setShortcut(.init(.a, modifiers: [.command, .option]), for: .showHistory)
        KeyboardShortcuts.setShortcut(.init(.s, modifiers: [.command, .option]), for: .readSelectedText)
        KeyboardShortcuts.setShortcut(.init(.x, modifiers: [.command, .option]), for: .takeScreenshot)
        
        // Set up keyboard shortcut handlers
        KeyboardShortcuts.onKeyUp(for: .startRecording) { [weak self] in
            // If about to start a fresh recording, make sure any previous
            // processing indicator is stopped and UI is reset.
            if let isRecording = self?.audioManager.isRecording, !isRecording {
                self?.stopTranscriptionIndicator()
            }
            self?.audioManager.toggleRecording()
        }
        
        KeyboardShortcuts.onKeyUp(for: .showHistory) { [weak self] in
            self?.showTranscriptionHistory()
        }
        
        KeyboardShortcuts.onKeyUp(for: .readSelectedText) { [weak self] in
            self?.handleReadSelectedTextToggle()
        }

        KeyboardShortcuts.onKeyUp(for: .takeScreenshot) { [weak self] in
            self?.takeInstantScreenshot()
        }

        // Set up audio manager
        audioManager = AudioTranscriptionManager()
        audioManager.delegate = self
        
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
    
    func takeInstantScreenshot() {
        // Take a screenshot of all displays
        let displayCount = CGDisplayCreateImage(CGMainDisplayID()) != nil ? 1 : 0

        // Get all active displays
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: 10)
        var displayCount32: UInt32 = 0
        CGGetActiveDisplayList(10, &displayIDs, &displayCount32)

        var screenshots: [NSImage] = []

        // Capture each display
        for i in 0..<Int(displayCount32) {
            if let screenShot = CGDisplayCreateImage(displayIDs[i]) {
                let nsImage = NSImage(cgImage: screenShot, size: NSSize(width: screenShot.width, height: screenShot.height))
                screenshots.append(nsImage)
            }
        }

        guard !screenshots.isEmpty else {
            let notification = NSUserNotification()
            notification.title = "Screenshot Failed"
            notification.informativeText = "Unable to capture screen"
            NSUserNotificationCenter.default.deliver(notification)
            return
        }

        // If multiple displays, combine them horizontally
        let finalImage: NSImage
        if screenshots.count > 1 {
            // Calculate total width and max height
            let totalWidth = screenshots.reduce(0) { $0 + $1.size.width }
            let maxHeight = screenshots.map { $0.size.height }.max() ?? 0

            finalImage = NSImage(size: NSSize(width: totalWidth, height: maxHeight))
            finalImage.lockFocus()

            var xOffset: CGFloat = 0
            for screenshot in screenshots {
                screenshot.draw(at: NSPoint(x: xOffset, y: 0),
                              from: NSRect.zero,
                              operation: .sourceOver,
                              fraction: 1.0)
                xOffset += screenshot.size.width
            }

            finalImage.unlockFocus()
        } else {
            finalImage = screenshots[0]
        }

        // Save to Desktop
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        let fileName = "Screenshot_\(timestamp).png"
        let desktopPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        let fileURL = desktopPath.appendingPathComponent(fileName)
        let filePath = fileURL.path

        // Convert to PNG data
        guard let tiffData = finalImage.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            let notification = NSUserNotification()
            notification.title = "Screenshot Failed"
            notification.informativeText = "Unable to process screenshot"
            NSUserNotificationCenter.default.deliver(notification)
            return
        }

        do {
            // Save to file
            try pngData.write(to: URL(fileURLWithPath: filePath))

            // Copy to clipboard
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setData(pngData, forType: .png)

            // Play sound effect
            NSSound(named: "Grab")?.play()

            // Show notification
            let notification = NSUserNotification()
            notification.title = "Screenshot Captured"
            notification.informativeText = "Saved to: \(fileName)"
            notification.subtitle = "Copied to clipboard"
            notification.soundName = nil // We're playing our own sound
            NSUserNotificationCenter.default.deliver(notification)

            print("📸 Screenshot saved to: \(filePath)")

        } catch {
            let notification = NSUserNotification()
            notification.title = "Screenshot Failed"
            notification.informativeText = "Unable to save screenshot: \(error.localizedDescription)"
            NSUserNotificationCenter.default.deliver(notification)
        }
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
                        } catch {
                            print("❌ Streaming TTS Error: \(error)")
                            
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
        
        // If not currently recording, reset to default icon.
        // When recording, the live level updates will take over UI shortly.
        if audioManager?.isRecording != true {
            if let button = statusItem.button {
                button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Voice Assistant")
                button.title = ""
            }
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
