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
        
        // Set up keyboard shortcut handlers
        KeyboardShortcuts.onKeyUp(for: .startRecording) { [weak self] in
            self?.audioManager.toggleRecording()
        }
        
        KeyboardShortcuts.onKeyUp(for: .showHistory) { [weak self] in
            self?.showTranscriptionHistory()
        }
        
        KeyboardShortcuts.onKeyUp(for: .readSelectedText) { [weak self] in
            self?.readSelectedText()
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
    
    func readSelectedText() {
        // Use Accessibility API to get selected text directly
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedElement: CFTypeRef?
        
        // Get the currently focused UI element
        let result = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        
        if result == .success, let element = focusedElement {
            let axElement = element as! AXUIElement
            var selectedTextValue: CFTypeRef?
            
            // Try to get selected text
            let selectedTextResult = AXUIElementCopyAttributeValue(axElement, kAXSelectedTextAttribute as CFString, &selectedTextValue)
            
            if selectedTextResult == .success, let selectedText = selectedTextValue as? String, !selectedText.isEmpty {
                print("📖 Selected text for streaming TTS: \(selectedText)")
                
                // Try to stream speech with our streaming components
                if let audioCollector = audioCollector, let streamingPlayer = streamingPlayer {
                    Task {
                        do {
                            let notification = NSUserNotification()
                            notification.title = "Streaming TTS"
                            notification.informativeText = "Starting streaming synthesis: \(selectedText.prefix(50))\(selectedText.count > 50 ? "..." : "")"
                            NSUserNotificationCenter.default.deliver(notification)
                            
                            // Stream audio with sentence pauses
                            try await streamingPlayer.playTextWithSentencePauses(selectedText, audioCollector: audioCollector, pauseDurationMs: 0)
                            
                            let completionNotification = NSUserNotification()
                            completionNotification.title = "Streaming TTS Complete"
                            completionNotification.informativeText = "Finished streaming selected text"
                            NSUserNotificationCenter.default.deliver(completionNotification)
                            
                        } catch {
                            print("❌ Streaming TTS Error: \(error)")
                            
                            let errorNotification = NSUserNotification()
                            errorNotification.title = "Streaming TTS Error"
                            errorNotification.informativeText = "Failed to stream text: \(error.localizedDescription)"
                            NSUserNotificationCenter.default.deliver(errorNotification)
                            
                            // Fallback: put text in clipboard
                            DispatchQueue.main.async {
                                let pasteboard = NSPasteboard.general
                                pasteboard.clearContents()
                                pasteboard.setString(selectedText, forType: .string)
                                
                                let fallbackNotification = NSUserNotification()
                                fallbackNotification.title = "Text Copied to Clipboard"
                                fallbackNotification.informativeText = "Streaming failed, text copied instead"
                                NSUserNotificationCenter.default.deliver(fallbackNotification)
                            }
                        }
                    }
                } else {
                    // Fallback: put the selected text in clipboard
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(selectedText, forType: .string)
                    
                    let notification = NSUserNotification()
                    notification.title = "Selected Text Copied"
                    notification.informativeText = "Streaming TTS not available, text copied to clipboard: \(selectedText.prefix(100))\(selectedText.count > 100 ? "..." : "")"
                    NSUserNotificationCenter.default.deliver(notification)
                }
            } else {
                print("⚠️ No text selected or accessibility API failed")
                
                let notification = NSUserNotification()
                notification.title = "No Text Selected"
                notification.informativeText = "Please select some text first or app doesn't support accessibility"
                NSUserNotificationCenter.default.deliver(notification)
            }
        } else {
            print("⚠️ Could not get focused UI element")
            
            let notification = NSUserNotification()
            notification.title = "No Focused Element"
            notification.informativeText = "Could not access the current application"
            NSUserNotificationCenter.default.deliver(notification)
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
