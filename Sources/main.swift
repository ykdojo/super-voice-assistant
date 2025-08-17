import Cocoa
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let startRecording = Self("startRecording")
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var isRecording = false
    
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
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        
        // Set default keyboard shortcut (Shift+Alt+Z)
        KeyboardShortcuts.setShortcut(.init(.z, modifiers: [.shift, .option]), for: .startRecording)
        
        // Set up keyboard shortcut handler
        KeyboardShortcuts.onKeyUp(for: .startRecording) { [weak self] in
            self?.toggleRecording()
        }
    }
    
    func toggleRecording() {
        isRecording.toggle()
        
        // Update icon to show recording state
        if let button = statusItem.button {
            if isRecording {
                button.image = NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: "Recording")
                print("🎤 Recording started...")
            } else {
                button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Voice Assistant")
                print("⏹ Recording stopped")
            }
        }
    }
}

// Create and run the app
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // Hide from dock
app.run()
