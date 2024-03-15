import AppKit

class SettingsView: NSView, NSTextFieldDelegate {
    // MARK: Controls

    lazy var launchAtLoginCheckbox: NSButton = {
        let checkbox = NSButton(checkboxWithTitle: "Launch at login", target: self, action: #selector(launchAtLoginCheckboxClicked))
        checkbox.state = PropertiesManager.shouldLaunchOnLogin ? .on : .off
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        return checkbox
    }()

    lazy var enableLoggingCheckbox: NSButton = {
        let checkbox = NSButton(
            checkboxWithTitle: "Enable loggin to ~/.wakatime/macos-wakatime.log",
            target: self,
            action: #selector(enableLoggingCheckboxClicked)
        )
        checkbox.state = PropertiesManager.shouldLogToFile ? .on : .off
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

    lazy var versionLabel: NSTextField = {
        let versionString = "Version: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")"
        let versionLabel = NSTextField(labelWithString: versionString)
        versionLabel.translatesAutoresizingMaskIntoConstraints = false
        return versionLabel
    }()

    init() {
        super.init(frame: .zero)

        addSubview(launchAtLoginCheckbox)
        addSubview(enableLoggingCheckbox)
        addSubview(apiKeyLabel)
        addSubview(textField)
        addSubview(versionLabel)

        setupConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func launchAtLoginCheckboxClicked() {
        PropertiesManager.shouldLaunchOnLogin = launchAtLoginCheckbox.state == .on
        if launchAtLoginCheckbox.state == .on {
            SettingsManager.registerAsLoginItem()
        } else {
            SettingsManager.unregisterAsLoginItem()
        }
    }

    @objc func enableLoggingCheckboxClicked() {
        PropertiesManager.shouldLaunchOnLogin = enableLoggingCheckbox.state == .on
        if enableLoggingCheckbox.state == .on {
            PropertiesManager.shouldLogToFile = true
        } else {
            PropertiesManager.shouldLogToFile = false
        }
    }

    func controlTextDidChange(_ obj: Notification) {
        ConfigFile.setSetting(section: "settings", key: "api_key", val: textField.stringValue)
    }

    private func setupConstraints() {
        let constraints = [
            launchAtLoginCheckbox.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            launchAtLoginCheckbox.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),

            enableLoggingCheckbox.topAnchor.constraint(equalTo: launchAtLoginCheckbox.bottomAnchor, constant: 10),
            enableLoggingCheckbox.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),

            apiKeyLabel.topAnchor.constraint(equalTo: enableLoggingCheckbox.bottomAnchor, constant: 30),
            apiKeyLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),

            textField.topAnchor.constraint(equalTo: apiKeyLabel.bottomAnchor, constant: 10),
            textField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),

            versionLabel.topAnchor.constraint(equalTo: textField.bottomAnchor, constant: 10),
            versionLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            versionLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
        ]
        NSLayoutConstraint.activate(constraints)
    }
}
