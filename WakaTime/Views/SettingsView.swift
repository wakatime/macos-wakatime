import AppKit

class SettingsView: NSView, NSTextFieldDelegate {
    // MARK: State

    var apiKey: String = ""

    var automaticallyDownloadUpdates: Bool {
        get {
            PropertiesManager.shouldAutomaticallyDownloadUpdates
        }

        set {
            PropertiesManager.shouldAutomaticallyDownloadUpdates = newValue

            guard let appDelegate = NSApplication.shared.delegate as? AppDelegate else { return }

            appDelegate.updaterController.updater.automaticallyDownloadsUpdates = newValue
        }
    }

    // MARK: Controls

    lazy var launchAtLoginCheckbox: NSButton = {
        let checkbox = NSButton(checkboxWithTitle: "Launch at login", target: self, action: #selector(launchAtLoginCheckboxClicked))
        checkbox.state = PropertiesManager.shouldLaunchOnLogin ? .on : .off
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        return checkbox
    }()

    lazy var automaticallyDownloadUpdatesCheckbox: NSButton = {
        let checkbox = NSButton(
            checkboxWithTitle: "Automatically download updates",
            target: self,
            action: #selector(automaticallyDownloadUpdatesClicked)
        )
        checkbox.state = automaticallyDownloadUpdates ? .on : .off
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        return checkbox
    }()

    lazy var apiKeyLabel: NSTextField = {
        let apiKeyLabel = NSTextField(labelWithString: "WakaTime API Key:")
        apiKeyLabel.translatesAutoresizingMaskIntoConstraints = false
        return apiKeyLabel
    }()

    lazy var textField: WKTextField = {
        let textField = WKTextField(frame: .zero)
        textField.stringValue = ConfigFile.getSetting(section: "settings", key: "api_key") ?? ""
        textField.delegate = self
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()

    lazy var saveButton: NSButton = {
        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveButtonClicked))
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.keyEquivalent = "\r"
        return saveButton
    }()

    lazy var cancelButton: NSButton = {
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelButtonClicked))
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.keyEquivalent = "\u{1b}"
        return cancelButton
    }()

    lazy var stackView: NSStackView = {
        let stackView = NSStackView(views: [saveButton, cancelButton])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .horizontal
        stackView.spacing = 10
        return stackView
    }()

    lazy var versionLabel: NSTextField = {
        let versionString = "Version: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")"
        let versionLabel = NSTextField(labelWithString: versionString)
        versionLabel.translatesAutoresizingMaskIntoConstraints = false
        return versionLabel
    }()

    init() {
        super.init(frame: .zero)

        addSubview(launchAtLoginCheckbox)
        addSubview(automaticallyDownloadUpdatesCheckbox)
        addSubview(apiKeyLabel)
        addSubview(textField)
        addSubview(stackView)
        addSubview(versionLabel)

        setupConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        window?.defaultButtonCell = saveButton.cell as? NSButtonCell
    }

    @objc func launchAtLoginCheckboxClicked() {
        PropertiesManager.shouldLaunchOnLogin = launchAtLoginCheckbox.state == .on
        if launchAtLoginCheckbox.state == .on {
            SettingsManager.registerAsLoginItem()
        } else {
            SettingsManager.unregisterAsLoginItem()
        }
    }

    @objc func automaticallyDownloadUpdatesClicked() {
        automaticallyDownloadUpdates = automaticallyDownloadUpdatesCheckbox.state == .on
    }

    @objc func saveButtonClicked() {
        ConfigFile.setSetting(section: "settings", key: "api_key", val: textField.stringValue)
        self.window?.close()
    }

    @objc func cancelButtonClicked() {
        self.window?.close()
    }

    func controlTextDidChange(_ obj: Notification) {
        apiKey = textField.stringValue
    }

    private func setupConstraints() {
        let constraints = [
            launchAtLoginCheckbox.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            launchAtLoginCheckbox.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),

            automaticallyDownloadUpdatesCheckbox.topAnchor.constraint(equalTo: launchAtLoginCheckbox.bottomAnchor, constant: 20),
            automaticallyDownloadUpdatesCheckbox.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),

            apiKeyLabel.topAnchor.constraint(equalTo: automaticallyDownloadUpdatesCheckbox.bottomAnchor, constant: 20),
            apiKeyLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),

            textField.topAnchor.constraint(equalTo: apiKeyLabel.bottomAnchor, constant: 10),
            textField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),

            stackView.topAnchor.constraint(equalTo: textField.bottomAnchor, constant: 4),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stackView.heightAnchor.constraint(equalToConstant: 40),

            versionLabel.topAnchor.constraint(equalTo: stackView.bottomAnchor, constant: 10),
            versionLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            versionLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            versionLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20)
        ]
        NSLayoutConstraint.activate(constraints)
    }
}
