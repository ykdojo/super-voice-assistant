import Cocoa

class StatsWindow: NSWindow {
    private let titleLabel: NSTextField
    private let countLabel: NSTextField
    private let descriptionLabel: NSTextField
    private let closeButton: NSButton
    
    init() {
        let contentRect = NSRect(x: 0, y: 0, width: 400, height: 200)
        
        // Initialize properties before super.init
        self.titleLabel = NSTextField(labelWithString: "Usage Statistics")
        self.countLabel = NSTextField(labelWithString: "0")
        self.descriptionLabel = NSTextField(labelWithString: "Total Transcriptions")
        self.closeButton = NSButton(title: "Close", target: nil, action: #selector(closeWindow))
        
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        self.title = "Statistics"
        self.level = .floating
        self.isReleasedWhenClosed = false
        self.hidesOnDeactivate = true
        
        setupUI()
        updateStats()
    }
    
    private func setupUI() {
        let contentView = NSView(frame: self.frame)
        self.contentView = contentView
        
        // Configure title label
        titleLabel.font = .boldSystemFont(ofSize: 16)
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        // Configure count label (the big number)
        countLabel.font = .systemFont(ofSize: 48, weight: .bold)
        countLabel.alignment = .center
        countLabel.textColor = .controlAccentColor
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(countLabel)
        
        // Configure description label
        descriptionLabel.font = .systemFont(ofSize: 14)
        descriptionLabel.alignment = .center
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(descriptionLabel)
        
        // Configure close button
        closeButton.target = self
        closeButton.bezelStyle = .rounded
        closeButton.keyEquivalent = "\u{1b}"
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(closeButton)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            
            countLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -10),
            countLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            
            descriptionLabel.topAnchor.constraint(equalTo: countLabel.bottomAnchor, constant: 5),
            descriptionLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            
            closeButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            closeButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 100)
        ])
    }
    
    private func updateStats() {
        let total = TranscriptionStats.shared.getTotalTranscriptions()
        countLabel.stringValue = "\(total)"
    }
    
    func show() {
        center()
        
        // Ensure the app is active and window comes to front
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
        
        // Refresh stats when showing
        updateStats()
    }
    
    @objc private func closeWindow() {
        close()
    }
}