import Cocoa
import Combine
import SharedModels

class AudioDevicesViewController: NSViewController {
    private var deviceManager = AudioDeviceManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    private let inputLabel = NSTextField(labelWithString: "Input Device")
    private let outputLabel = NSTextField(labelWithString: "Output Device")
    
    private let inputSystemDefaultRadio = NSButton(radioButtonWithTitle: "Follow System Default", target: nil, action: nil)
    private let inputSpecificRadio = NSButton(radioButtonWithTitle: "Use Specific Device:", target: nil, action: nil)
    private let inputDevicePopup = NSPopUpButton()
    
    private let outputSystemDefaultRadio = NSButton(radioButtonWithTitle: "Follow System Default", target: nil, action: nil)
    private let outputSpecificRadio = NSButton(radioButtonWithTitle: "Use Specific Device:", target: nil, action: nil)
    private let outputDevicePopup = NSPopUpButton()
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindToDeviceManager()
        updateUIState()
    }
    
    private func setupUI() {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)
        
        inputLabel.font = .boldSystemFont(ofSize: 14)
        outputLabel.font = .boldSystemFont(ofSize: 14)
        
        inputSystemDefaultRadio.target = self
        inputSystemDefaultRadio.action = #selector(inputSystemDefaultChanged)
        inputSpecificRadio.target = self
        inputSpecificRadio.action = #selector(inputSpecificChanged)
        
        outputSystemDefaultRadio.target = self
        outputSystemDefaultRadio.action = #selector(outputSystemDefaultChanged)
        outputSpecificRadio.target = self
        outputSpecificRadio.action = #selector(outputSpecificChanged)
        
        inputDevicePopup.target = self
        inputDevicePopup.action = #selector(inputDeviceChanged)
        outputDevicePopup.target = self
        outputDevicePopup.action = #selector(outputDeviceChanged)
        
        let divider = NSBox()
        divider.boxType = .separator
        
        let views = [
            inputLabel,
            inputSystemDefaultRadio,
            inputSpecificRadio,
            inputDevicePopup,
            divider,
            outputLabel,
            outputSystemDefaultRadio,
            outputSpecificRadio,
            outputDevicePopup
        ]
        
        views.forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            container.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            container.widthAnchor.constraint(equalToConstant: 400),
            
            inputLabel.topAnchor.constraint(equalTo: container.topAnchor),
            inputLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            
            inputSystemDefaultRadio.topAnchor.constraint(equalTo: inputLabel.bottomAnchor, constant: 12),
            inputSystemDefaultRadio.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            
            inputSpecificRadio.topAnchor.constraint(equalTo: inputSystemDefaultRadio.bottomAnchor, constant: 8),
            inputSpecificRadio.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            
            inputDevicePopup.centerYAnchor.constraint(equalTo: inputSpecificRadio.centerYAnchor),
            inputDevicePopup.leadingAnchor.constraint(equalTo: inputSpecificRadio.trailingAnchor, constant: 8),
            inputDevicePopup.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            inputDevicePopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
            
            divider.topAnchor.constraint(equalTo: inputDevicePopup.bottomAnchor, constant: 24),
            divider.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            outputLabel.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 24),
            outputLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            
            outputSystemDefaultRadio.topAnchor.constraint(equalTo: outputLabel.bottomAnchor, constant: 12),
            outputSystemDefaultRadio.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            
            outputSpecificRadio.topAnchor.constraint(equalTo: outputSystemDefaultRadio.bottomAnchor, constant: 8),
            outputSpecificRadio.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            
            outputDevicePopup.centerYAnchor.constraint(equalTo: outputSpecificRadio.centerYAnchor),
            outputDevicePopup.leadingAnchor.constraint(equalTo: outputSpecificRadio.trailingAnchor, constant: 8),
            outputDevicePopup.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            outputDevicePopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
            outputDevicePopup.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }
    
    private func bindToDeviceManager() {
        deviceManager.$availableInputDevices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] devices in
                self?.updateInputDeviceList(devices)
            }
            .store(in: &cancellables)
        
        deviceManager.$availableOutputDevices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] devices in
                self?.updateOutputDeviceList(devices)
            }
            .store(in: &cancellables)
        
        deviceManager.$useSystemDefaultInput
            .receive(on: DispatchQueue.main)
            .sink { [weak self] useDefault in
                self?.inputSystemDefaultRadio.state = useDefault ? .on : .off
                self?.inputSpecificRadio.state = useDefault ? .off : .on
                self?.inputDevicePopup.isEnabled = !useDefault
            }
            .store(in: &cancellables)
        
        deviceManager.$useSystemDefaultOutput
            .receive(on: DispatchQueue.main)
            .sink { [weak self] useDefault in
                self?.outputSystemDefaultRadio.state = useDefault ? .on : .off
                self?.outputSpecificRadio.state = useDefault ? .off : .on
                self?.outputDevicePopup.isEnabled = !useDefault
            }
            .store(in: &cancellables)
    }
    
    private func updateInputDeviceList(_ devices: [AudioDevice]) {
        inputDevicePopup.removeAllItems()
        
        let realDevices = devices.filter { $0.uid != "system_default" }
        for device in realDevices {
            inputDevicePopup.addItem(withTitle: device.name)
            inputDevicePopup.lastItem?.representedObject = device.uid
        }
        
        if let selectedUID = deviceManager.selectedInputDeviceUID,
           let index = realDevices.firstIndex(where: { $0.uid == selectedUID }) {
            inputDevicePopup.selectItem(at: index)
        }
    }
    
    private func updateOutputDeviceList(_ devices: [AudioDevice]) {
        outputDevicePopup.removeAllItems()
        
        let realDevices = devices.filter { $0.uid != "system_default" }
        for device in realDevices {
            outputDevicePopup.addItem(withTitle: device.name)
            outputDevicePopup.lastItem?.representedObject = device.uid
        }
        
        if let selectedUID = deviceManager.selectedOutputDeviceUID,
           let index = realDevices.firstIndex(where: { $0.uid == selectedUID }) {
            outputDevicePopup.selectItem(at: index)
        }
    }
    
    private func updateUIState() {
        inputSystemDefaultRadio.state = deviceManager.useSystemDefaultInput ? .on : .off
        inputSpecificRadio.state = deviceManager.useSystemDefaultInput ? .off : .on
        inputDevicePopup.isEnabled = !deviceManager.useSystemDefaultInput
        
        outputSystemDefaultRadio.state = deviceManager.useSystemDefaultOutput ? .on : .off
        outputSpecificRadio.state = deviceManager.useSystemDefaultOutput ? .off : .on
        outputDevicePopup.isEnabled = !deviceManager.useSystemDefaultOutput
    }
    
    @objc private func inputSystemDefaultChanged() {
        deviceManager.useSystemDefaultInput = true
        deviceManager.savePreferences()
        updateUIState()
    }
    
    @objc private func inputSpecificChanged() {
        deviceManager.useSystemDefaultInput = false
        if inputDevicePopup.indexOfSelectedItem >= 0,
           let uid = inputDevicePopup.selectedItem?.representedObject as? String {
            deviceManager.selectedInputDeviceUID = uid
        }
        deviceManager.savePreferences()
        updateUIState()
    }
    
    @objc private func outputSystemDefaultChanged() {
        deviceManager.useSystemDefaultOutput = true
        deviceManager.savePreferences()
        updateUIState()
    }
    
    @objc private func outputSpecificChanged() {
        deviceManager.useSystemDefaultOutput = false
        if outputDevicePopup.indexOfSelectedItem >= 0,
           let uid = outputDevicePopup.selectedItem?.representedObject as? String {
            deviceManager.selectedOutputDeviceUID = uid
        }
        deviceManager.savePreferences()
        updateUIState()
    }
    
    @objc private func inputDeviceChanged() {
        guard let uid = inputDevicePopup.selectedItem?.representedObject as? String else { return }
        deviceManager.selectedInputDeviceUID = uid
        deviceManager.savePreferences()
    }
    
    @objc private func outputDeviceChanged() {
        guard let uid = outputDevicePopup.selectedItem?.representedObject as? String else { return }
        deviceManager.selectedOutputDeviceUID = uid
        deviceManager.savePreferences()
    }
}