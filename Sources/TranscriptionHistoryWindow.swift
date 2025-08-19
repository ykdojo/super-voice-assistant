import Cocoa

class TranscriptionHistoryWindow: NSWindow, NSTableViewDelegate, NSTableViewDataSource {
    private let tableView: NSTableView
    private let scrollView: NSScrollView
    private let clearButton: NSButton
    private let closeButton: NSButton
    private let titleLabel: NSTextField
    private var entries: [TranscriptionEntry] = []
    
    init() {
        let contentRect = NSRect(x: 0, y: 0, width: 800, height: 500)
        
        // Initialize properties before super.init
        self.tableView = NSTableView()
        self.scrollView = NSScrollView()
        self.clearButton = NSButton(title: "Clear History", target: nil, action: #selector(clearHistory))
        self.closeButton = NSButton(title: "Close", target: nil, action: #selector(closeWindow))
        self.titleLabel = NSTextField(labelWithString: "Transcription History")
        
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        self.title = "Transcription History"
        self.level = .floating
        self.isReleasedWhenClosed = false
        self.hidesOnDeactivate = false
        
        setupUI()
        loadEntries()
    }
    
    private func setupUI() {
        let contentView = NSView(frame: self.frame)
        self.contentView = contentView
        
        // Configure title label
        titleLabel.font = .boldSystemFont(ofSize: 14)
        titleLabel.alignment = .left
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        // Configure scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.borderType = .lineBorder
        contentView.addSubview(scrollView)
        
        // Configure table view
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = 60
        tableView.gridStyleMask = .solidHorizontalGridLineMask
        tableView.allowsTypeSelect = true
        tableView.usesAlternatingRowBackgroundColors = true
        
        // Create columns in order: Transcription, Action, Time
        let textColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("text"))
        textColumn.title = "Transcription"
        textColumn.width = 500
        tableView.addTableColumn(textColumn)
        
        let actionColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("action"))
        actionColumn.title = "Action"
        actionColumn.width = 80
        tableView.addTableColumn(actionColumn)
        
        let dateColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("date"))
        dateColumn.title = "Time"
        dateColumn.width = 180
        tableView.addTableColumn(dateColumn)
        
        scrollView.documentView = tableView
        
        // Configure buttons
        clearButton.target = self
        clearButton.bezelStyle = .rounded
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(clearButton)
        
        closeButton.target = self
        closeButton.bezelStyle = .rounded
        closeButton.keyEquivalent = "\u{1b}"
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(closeButton)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: clearButton.topAnchor, constant: -20),
            
            clearButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            clearButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor, constant: -75),
            clearButton.widthAnchor.constraint(equalToConstant: 140),
            
            closeButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            closeButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor, constant: 75),
            closeButton.widthAnchor.constraint(equalToConstant: 140)
        ])
    }
    
    private func loadEntries() {
        entries = TranscriptionHistory.shared.getEntries()
        tableView.reloadData()
        
        if entries.isEmpty {
            titleLabel.stringValue = "No transcription history"
            clearButton.isEnabled = false
        } else {
            titleLabel.stringValue = "Transcription History (\(entries.count) entries)"
            clearButton.isEnabled = true
        }
    }
    
    func show() {
        center()
        makeKeyAndOrderFront(nil)
        loadEntries() // Refresh when showing
        
        // Select first row if available
        if !entries.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }
    
    @objc private func clearHistory() {
        let alert = NSAlert()
        alert.messageText = "Clear History"
        alert.informativeText = "Are you sure you want to clear all transcription history?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            TranscriptionHistory.shared.clearHistory()
            loadEntries()
        }
    }
    
    @objc private func closeWindow() {
        close()
    }
    
    @objc private func copyTranscription(_ sender: NSButton) {
        let row = sender.tag
        guard row >= 0 && row < entries.count else { return }
        
        let text = entries[row].text
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Update button title temporarily
        sender.title = "Copied!"
        sender.isEnabled = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            sender.title = "Copy"
            sender.isEnabled = true
        }
    }
    
    // MARK: - NSTableViewDataSource
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return entries.count
    }
    
    // MARK: - NSTableViewDelegate
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < entries.count else { return nil }
        let entry = entries[row]
        
        let cellView = NSView()
        
        if tableColumn?.identifier.rawValue == "text" {
            let textField = NSTextField(labelWithString: entry.text)
            textField.font = .systemFont(ofSize: 12)
            textField.isEditable = false
            textField.isSelectable = true
            textField.isBordered = false
            textField.backgroundColor = .clear
            textField.lineBreakMode = .byTruncatingTail
            textField.maximumNumberOfLines = 2
            textField.frame = CGRect(x: 5, y: 5, width: 490, height: 50)
            cellView.addSubview(textField)
        } else if tableColumn?.identifier.rawValue == "action" {
            let button = NSButton(title: "Copy", target: self, action: #selector(copyTranscription(_:)))
            button.bezelStyle = .inline
            button.tag = row
            button.frame = CGRect(x: 5, y: 20, width: 70, height: 20)
            cellView.addSubview(button)
        } else if tableColumn?.identifier.rawValue == "date" {
            let textField = NSTextField(labelWithString: formatDate(entry.timestamp))
            textField.font = .systemFont(ofSize: 11)
            textField.textColor = .secondaryLabelColor
            textField.isEditable = false
            textField.isBordered = false
            textField.backgroundColor = .clear
            textField.lineBreakMode = .byWordWrapping
            textField.maximumNumberOfLines = 2
            textField.frame = CGRect(x: 5, y: 5, width: 170, height: 50)
            cellView.addSubview(textField)
        }
        
        return cellView
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
            return "Today " + formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            formatter.dateFormat = "h:mm a"
            return "Yesterday " + formatter.string(from: date)
        } else {
            formatter.dateFormat = "MMM d, h:mm a"
            return formatter.string(from: date)
        }
    }
}