import AppKit

class SettingsView: NSView, NSTextFieldDelegate, NSTextViewDelegate {
    // MARK: API Key

    lazy var apiKeyLabel: NSTextField = {
        NSTextField(labelWithString: "WakaTime API Key:")
    }()

    lazy var apiKeyTextField: WKTextField = {
        let textField = WKTextField(frame: .zero)
        textField.stringValue = ConfigFile.getSetting(section: "settings", key: "api_key") ?? ""
        textField.delegate = self
        return textField
    }()

    lazy var apiKeyStackView: NSStackView = {
        let stack = NSStackView(views: [apiKeyLabel, apiKeyTextField])
        stack.alignment = .leading
        stack.orientation = .vertical
        stack.spacing = 5
        return stack
    }()

    // MARK: Checkboxes

    lazy var launchAtLoginCheckbox: NSButton = {
        let checkbox = NSButton(
            checkboxWithTitle: "Launch at login",
            target: self,
            action: #selector(launchAtLoginCheckboxClicked)
        )
        checkbox.state = PropertiesManager.shouldLaunchOnLogin ? .on : .off
        return checkbox
    }()

    lazy var enableLoggingCheckbox: NSButton = {
        let checkbox = NSButton(
            checkboxWithTitle: "Enable logging to ~/.wakatime/macos-wakatime.log",
            target: self,
            action: #selector(enableLoggingCheckboxClicked)
        )
        checkbox.state = PropertiesManager.shouldLogToFile ? .on : .off
        return checkbox
    }()

    lazy var checkboxesStackView: NSStackView = {
        let stack = NSStackView(views: [launchAtLoginCheckbox, enableLoggingCheckbox])
        stack.alignment = .leading
        stack.orientation = .vertical
        stack.spacing = 10
        return stack
    }()

    // MARK: Whitelist/Blacklist

    lazy var filterTypeLabel: NSTextField = {
        NSTextField(labelWithString: "Logging Style:")
    }()

    lazy var filterSegmentedControl: NSSegmentedControl = {
        let control = NSSegmentedControl()
        control.segmentStyle = .texturedRounded
        control.segmentCount = 2
        control.setLabel("All except blacklisted sites", forSegment: 0)
        control.setLabel("Only whitelisted sites", forSegment: 1)
        control.trackingMode = .selectOne // Ensure only one option can be selected at a time
        control.action = #selector(segmentedControlDidChange(_:))
        return control
    }()

    lazy var filterListLabel: NSTextField = {
        NSTextField(labelWithString: "")
    }()

    lazy var filterTextView: NSTextView = {
        let textView = NSTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.containerSize = NSSize(width: self.bounds.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.delegate = self
        return textView
    }()

    lazy var filterScrollView: NSScrollView = {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.documentView = filterTextView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100).isActive = true
        return scrollView
    }()

    lazy var filterRemarksLabel: NSTextField = {
        var label = NSTextField(labelWithString: "")
        label.lineBreakMode = .byWordWrapping // Enable word wrapping
        label.maximumNumberOfLines = 0 // Set to 0 to allow unlimited lines
        label.preferredMaxLayoutWidth = 380
        return label
    }()

    lazy var filterStackView: NSStackView = {
        let stack = NSStackView(views: [
            filterTypeLabel,
            filterSegmentedControl,
            filterListLabel,
            filterScrollView,
            filterRemarksLabel
        ])
        stack.alignment = .leading
        stack.orientation = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    // MARK: Version Label

    lazy var versionLabel: NSTextField = {
        let versionString = "Version: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")"
        let versionLabel = NSTextField(labelWithString: versionString)
        return versionLabel
    }()

    lazy var stackView: NSStackView = {
        let stackView = NSStackView(views: [
            apiKeyStackView,
            checkboxesStackView,
            filterStackView,
            versionLabel
        ])
        stackView.alignment = .leading
        stackView.orientation = .vertical
        stackView.spacing = 25
        stackView.distribution = .equalSpacing
        stackView.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addConstraint(
            NSLayoutConstraint(
                item: filterStackView,
                attribute: .width,
                relatedBy: .equal,
                toItem: stackView,
                attribute: .width,
                multiplier: 1,
                constant: -(stackView.edgeInsets.left + stackView.edgeInsets.right)
            )
        )
        return stackView
    }()

    // MARK: Lifecycle

    init() {
        super.init(frame: .zero)

        addSubview(stackView)
        setupConstraints()

        updateFilterControls(animate: false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Callbacks

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

    @objc func segmentedControlDidChange(_ sender: NSSegmentedControl) {
        PropertiesManager.filterType = sender.selectedSegment == 0 ? .blacklist : .whitelist
        updateFilterControls(animate: true)
    }

    // MARK: NSTextFieldDelegate

    func controlTextDidChange(_ obj: Notification) {
        ConfigFile.setSetting(section: "settings", key: "api_key", val: apiKeyTextField.stringValue)
    }

    // MARK: NSTextViewDelegate

    func textDidChange(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView else { return }

        switch PropertiesManager.filterType {
            case .blacklist:
                PropertiesManager.blacklist = textView.string
            case .whitelist:
                PropertiesManager.whitelist = textView.string
        }
    }

    // MARK: Constraints

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
        ])
    }

    // MARK: State Helpers

    private func updateFilterControls(animate: Bool) {
        let blacklistTitle = "Blacklist:"
        let blacklistRemarks =
            "Sites that you don't want to show in your reports. " +
            "One line per site."
        let whitelistTitle = "Whitelist:"
        let whitelistRemarks =
            "Sites that you want to show in your reports. " +
            "You can assign URL to project by adding @@YourProject at the end of line. " +
            "One line per site."

        var title: String
        var remarks: String
        var list: String
        var selectedSegment: Int
        switch PropertiesManager.filterType {
            case .blacklist:
                title = blacklistTitle
                remarks = blacklistRemarks
                list = PropertiesManager.blacklist
                selectedSegment = 0
            case .whitelist:
                title = whitelistTitle
                remarks = whitelistRemarks
                list = PropertiesManager.whitelist
                selectedSegment = 1
        }

        filterListLabel.stringValue = title
        filterRemarksLabel.stringValue = remarks
        filterTextView.string = list
        filterSegmentedControl.setSelected(true, forSegment: selectedSegment)

        adjustWindowSize(animate: animate)
    }

    func adjustWindowSize(animate: Bool) {
        guard let window = self.window else { return }

        let newHeight = stackView.fittingSize.height + 70

        var newWindowFrame = window.frame // window.frameRect(forContentRect: NSRect(origin: window.frame.origin, size: newWindowSize))
        newWindowFrame.size.height = newHeight
        newWindowFrame.origin.y += window.frame.height - newWindowFrame.height // Adjust origin to keep the top-left corner stationary

        window.setFrame(newWindowFrame, display: true, animate: animate)
    }
}
