import Cocoa
import SwiftUI

enum ManagerTab: Int {
    case settings = 0
    case history = 1
    case statistics = 2
    case audioDevices = 3
}

class UnifiedManagerWindow: NSWindowController {
    private var tabViewController: NSTabViewController!
    private var historyViewController: TranscriptionHistoryViewController?
    private var statsViewController: StatsViewController?
    private var settingsController: SettingsWindowController?
    private var audioDevicesViewController: AudioDevicesViewController?
    
    override init(window: NSWindow?) {
        // Create the main window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 850, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Super Voice Assistant"
        window.minSize = NSSize(width: 600, height: 400)
        
        super.init(window: window)
        
        setupTabView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupTabView() {
        tabViewController = NSTabViewController()
        tabViewController.tabStyle = .toolbar
        
        // Settings Tab - Use existing SettingsWindowController's view
        if settingsController == nil {
            settingsController = SettingsWindowController()
        }
        let settingsViewController = NSViewController()
        settingsViewController.view = settingsController!.window!.contentView!
        let settingsTab = NSTabViewItem(viewController: settingsViewController)
        settingsTab.label = "Settings"
        settingsTab.image = NSImage(systemSymbolName: "gear", accessibilityDescription: "Settings")
        tabViewController.addTabViewItem(settingsTab)
        
        // History Tab - Use the new TranscriptionHistoryViewController
        historyViewController = TranscriptionHistoryViewController()
        let historyTab = NSTabViewItem(viewController: historyViewController!)
        historyTab.label = "History"
        historyTab.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "History")
        tabViewController.addTabViewItem(historyTab)
        
        // Statistics Tab - Use the new StatsViewController
        statsViewController = StatsViewController()
        let statsTab = NSTabViewItem(viewController: statsViewController!)
        statsTab.label = "Statistics"
        statsTab.image = NSImage(systemSymbolName: "chart.bar", accessibilityDescription: "Statistics")
        tabViewController.addTabViewItem(statsTab)
        
        // Audio Devices Tab
        audioDevicesViewController = AudioDevicesViewController()
        let audioDevicesTab = NSTabViewItem(viewController: audioDevicesViewController!)
        audioDevicesTab.label = "Audio Devices"
        audioDevicesTab.image = NSImage(systemSymbolName: "speaker.wave.2", accessibilityDescription: "Audio Devices")
        tabViewController.addTabViewItem(audioDevicesTab)
        
        window?.contentViewController = tabViewController
    }
    
    func showWindow(tab: ManagerTab? = nil) {
        // If a specific tab is requested, switch to it
        if let tab = tab {
            tabViewController.selectedTabViewItemIndex = tab.rawValue
            
            // If showing history tab, refresh it (even if already visible)
            if tab == .history {
                historyViewController?.refreshHistory()
            }
        }
        
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
