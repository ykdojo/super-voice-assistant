import Cocoa

class StatsViewController: NSViewController {
    private let titleLabel: NSTextField
    private let countLabel: NSTextField
    private let descriptionLabel: NSTextField
    private let closeButton: NSButton
    
    init() {
        // Initialize properties before super.init
        self.titleLabel = NSTextField(labelWithString: "Usage Statistics")
        self.countLabel = NSTextField(labelWithString: "0")
        self.descriptionLabel = NSTextField(labelWithString: "Total Transcriptions")
        self.closeButton = NSButton(title: "Close", target: nil, action: #selector(closeWindow))
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        setupUI()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateStats()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        // Refresh stats when view appears
        updateStats()
    }
    
    private func setupUI() {
        // Configure title label
        titleLabel.font = .boldSystemFont(ofSize: 16)
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        // Configure count label (the big number)
        countLabel.font = .systemFont(ofSize: 48, weight: .bold)
        countLabel.alignment = .center
        countLabel.textColor = .controlAccentColor
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(countLabel)
        
        // Configure description label
        descriptionLabel.font = .systemFont(ofSize: 14)
        descriptionLabel.alignment = .center
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(descriptionLabel)
        
        // Configure close button
        closeButton.target = self
        closeButton.bezelStyle = .rounded
        closeButton.keyEquivalent = "\u{1b}"
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeButton)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            countLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -10),
            countLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            descriptionLabel.topAnchor.constraint(equalTo: countLabel.bottomAnchor, constant: 5),
            descriptionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            closeButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            closeButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 100)
        ])
    }
    
    private func updateStats() {
        let total = TranscriptionStats.shared.getTotalTranscriptions()
        countLabel.stringValue = "\(total)"
    }
    
    @objc private func closeWindow() {
        // Close the parent window (UnifiedManagerWindow)
        view.window?.close()
    }
}
