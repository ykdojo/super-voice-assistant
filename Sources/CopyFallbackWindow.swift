import Cocoa

class CopyFallbackWindow: NSWindow {
    private let textView: NSTextView
    private let copyButton: NSButton
    private let titleLabel: NSTextField
    
    init(text: String) {
        let contentRect = NSRect(x: 0, y: 0, width: 400, height: 300)
        
        // Initialize properties before super.init
        self.textView = NSTextView()
        self.copyButton = NSButton(title: "Copy to Clipboard", target: nil, action: #selector(copyToClipboard))
        self.titleLabel = NSTextField(labelWithString: "Press ⌘C to copy or click the button below")
        
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        self.title = "Copy Text"
        self.level = .floating
        self.isReleasedWhenClosed = false
        self.hidesOnDeactivate = false
        
        let contentView = NSView(frame: contentRect)
        self.contentView = contentView
        
        // Configure titleLabel
        titleLabel.font = .systemFont(ofSize: 12)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.borderType = .lineBorder
        contentView.addSubview(scrollView)
        
        // Configure textView
        textView.string = text
        textView.isEditable = false
        textView.isRichText = false
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.backgroundColor = .textBackgroundColor
        textView.textColor = .textColor
        
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = CGSize(width: scrollView.frame.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        
        scrollView.documentView = textView
        
        // Configure copyButton
        copyButton.target = self
        copyButton.bezelStyle = .rounded
        copyButton.keyEquivalent = "\r"
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(copyButton)
        
        let closeButton = NSButton(title: "Close", target: self, action: #selector(closeWindow))
        closeButton.bezelStyle = .rounded
        closeButton.keyEquivalent = "\u{1b}"
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: copyButton.topAnchor, constant: -20),
            
            copyButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            copyButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor, constant: -75),
            copyButton.widthAnchor.constraint(equalToConstant: 140),
            
            closeButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            closeButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor, constant: 75),
            closeButton.widthAnchor.constraint(equalToConstant: 140)
        ])
        
        selectAllText()
    }
    
    func show() {
        center()
        makeKeyAndOrderFront(nil)
        
        DispatchQueue.main.async { [weak self] in
            self?.selectAllText()
        }
    }
    
    private func selectAllText() {
        textView.selectAll(nil)
        makeFirstResponder(textView)
    }
    
    @objc private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(textView.string, forType: .string)
        
        titleLabel.stringValue = "✓ Copied to clipboard!"
        titleLabel.textColor = .systemGreen
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.close()
        }
    }
    
    @objc private func closeWindow() {
        close()
    }
}