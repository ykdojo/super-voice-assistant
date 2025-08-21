import Cocoa

class TranscriptionHistoryWindow: NSWindow, NSTableViewDelegate, NSTableViewDataSource {
    private let tableView: NSTableView
    private let scrollView: NSScrollView
    private let clearButton: NSButton
    private let refreshButton: NSButton
    private let closeButton: NSButton
    private let titleLabel: NSTextField
    private var entries: [TranscriptionEntry] = []
    
    init() {
        let contentRect = NSRect(x: 0, y: 0, width: 800, height: 500)
        
        // Initialize properties before super.init
        self.tableView = NSTableView()
        self.scrollView = NSScrollView()
        self.clearButton = NSButton(title: "Clear History", target: nil, action: #selector(clearHistory))
        self.refreshButton = NSButton(title: "Refresh", target: nil, action: #selector(refreshHistory))
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
        self.hidesOnDeactivate = true
        
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
        tableView.rowHeight = 80
        tableView.gridStyleMask = .solidHorizontalGridLineMask
        tableView.allowsTypeSelect = true
        tableView.usesAlternatingRowBackgroundColors = true
        
        // Create columns in order: Transcription, Actions, Time
        let textColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("text"))
        textColumn.title = "Transcription"
        textColumn.width = 280
        tableView.addTableColumn(textColumn)
        
        let actionColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("action"))
        actionColumn.title = "Actions"
        actionColumn.width = 125
        tableView.addTableColumn(actionColumn)
        
        let dateColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("date"))
        dateColumn.title = "Time"
        dateColumn.width = 200
        tableView.addTableColumn(dateColumn)
        
        scrollView.documentView = tableView
        
        // Configure buttons
        clearButton.target = self
        clearButton.bezelStyle = .rounded
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(clearButton)
        
        refreshButton.target = self
        refreshButton.bezelStyle = .rounded
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(refreshButton)
        
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
            clearButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            clearButton.widthAnchor.constraint(equalToConstant: 120),
            
            refreshButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            refreshButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            refreshButton.widthAnchor.constraint(equalToConstant: 100),
            
            closeButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            closeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            closeButton.widthAnchor.constraint(equalToConstant: 100)
        ])
    }
    
    private func loadEntries() {
        entries = TranscriptionHistory.shared.getEntries()
        tableView.reloadData()
        
        if entries.isEmpty {
            titleLabel.stringValue = "No transcription history"
            clearButton.isEnabled = false
        } else {
            titleLabel.stringValue = "Transcription History (\(entries.count) of max 100 entries)"
            clearButton.isEnabled = true
        }
    }
    
    func show() {
        center()
        
        // Ensure the app is active and window comes to front
        NSApp.activate(ignoringOtherApps: true)
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
    
    @objc func refreshHistory() {
        loadEntries()
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
    
    @objc private func copyAndClose(_ sender: NSButton) {
        let row = sender.tag
        guard row >= 0 && row < entries.count else { return }
        
        let text = entries[row].text
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Update button title temporarily to show feedback
        sender.title = "Copied!"
        sender.isEnabled = false
        
        // Close the window after a brief delay to show the feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.27) {
            self.close()
        }
    }
    
    @objc private func deleteTranscription(_ sender: NSButton) {
        let row = sender.tag
        guard row >= 0 && row < entries.count else { return }
        
        let alert = NSAlert()
        alert.messageText = "Delete Entry"
        alert.informativeText = "Are you sure you want to delete this transcription?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            TranscriptionHistory.shared.deleteEntry(at: row)
            loadEntries()
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
            let textField = NSTextField(wrappingLabelWithString: entry.text)
            textField.font = .systemFont(ofSize: 12)
            textField.isEditable = false
            textField.isSelectable = true
            textField.isBordered = false
            textField.backgroundColor = .clear
            textField.lineBreakMode = .byWordWrapping
            textField.maximumNumberOfLines = 2
            textField.translatesAutoresizingMaskIntoConstraints = false
            cellView.addSubview(textField)
            
            // Use constraints to properly contain the text field
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 5),
                textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -5),
                textField.topAnchor.constraint(equalTo: cellView.topAnchor, constant: 5),
                textField.bottomAnchor.constraint(equalTo: cellView.bottomAnchor, constant: -5)
            ])
        } else if tableColumn?.identifier.rawValue == "action" {
            let copyButton = NSButton(title: "Copy", target: self, action: #selector(copyTranscription(_:)))
            copyButton.bezelStyle = .inline
            copyButton.tag = row
            copyButton.frame = CGRect(x: 5, y: 55, width: 50, height: 18)
            cellView.addSubview(copyButton)
            
            let deleteButton = NSButton(title: "Delete", target: self, action: #selector(deleteTranscription(_:)))
            deleteButton.bezelStyle = .inline
            deleteButton.tag = row
            deleteButton.frame = CGRect(x: 60, y: 55, width: 55, height: 18)
            cellView.addSubview(deleteButton)
            
            let copyCloseButton = NSButton(title: "Copy & Close", target: self, action: #selector(copyAndClose(_:)))
            copyCloseButton.bezelStyle = .inline
            copyCloseButton.tag = row
            copyCloseButton.frame = CGRect(x: 5, y: 30, width: 110, height: 18)
            cellView.addSubview(copyCloseButton)
        } else if tableColumn?.identifier.rawValue == "date" {
            let textField = NSTextField(labelWithString: formatDate(entry.timestamp))
            textField.font = .systemFont(ofSize: 11)
            textField.textColor = .secondaryLabelColor
            textField.isEditable = false
            textField.isBordered = false
            textField.backgroundColor = .clear
            textField.lineBreakMode = .byWordWrapping
            textField.maximumNumberOfLines = 2
            textField.translatesAutoresizingMaskIntoConstraints = false
            cellView.addSubview(textField)
            
            // Top-align the date text
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 5),
                textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -5),
                textField.topAnchor.constraint(equalTo: cellView.topAnchor, constant: 5)
            ])
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