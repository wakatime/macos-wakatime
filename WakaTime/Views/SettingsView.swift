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

    // MARK: Domain Preference

    lazy var browserLabel: NSTextField = {
        var label = NSTextField(labelWithString: "The settings below are only applicable because you’ve enabled " +
            "monitoring a browser in the Monitored Apps menu.")
        label.lineBreakMode = .byWordWrapping // Enable word wrapping
        label.maximumNumberOfLines = 0 // Set to 0 to allow unlimited lines
        label.preferredMaxLayoutWidth = 380
        return label
    }()

    lazy var domainPreferenceLabel: NSTextField = {
        NSTextField(labelWithString: "Browser Tracking:")
    }()

    lazy var domainPreferenceControl: NSSegmentedControl = {
        let control = NSSegmentedControl()
        control.segmentStyle = .texturedRounded
        control.segmentCount = 2
        control.setLabel("Domain only", forSegment: 0)
        control.setLabel("Full url", forSegment: 1)
        control.trackingMode = .selectOne // Ensure only one option can be selected at a time
        control.action = #selector(domainPreferenceDidChange(_:))
        return control
    }()

    // MARK: Denylist/Allowlist

    lazy var filterTypeLabel: NSTextField = {
        NSTextField(labelWithString: "Browser Filter:")
    }()

    lazy var filterSegmentedControl: NSSegmentedControl = {
        let control = NSSegmentedControl()
        control.segmentStyle = .texturedRounded
        control.segmentCount = 2
        control.setLabel("All except denied sites", forSegment: 0)
        control.setLabel("Only allowed sites", forSegment: 1)
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
        textView.isRichText = false
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

    lazy var domainStackView: NSStackView = {
        let stack = NSStackView(views: [
            domainPreferenceLabel,
            domainPreferenceControl
        ])
        stack.alignment = .leading
        stack.orientation = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
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
            browserLabel,
            domainStackView,
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
        setBrowserVisibility()
        updateDomainPreference(animate: false)
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
        PropertiesManager.shouldLogToFile = enableLoggingCheckbox.state == .on
        if enableLoggingCheckbox.state == .on {
            PropertiesManager.shouldLogToFile = true
        } else {
            PropertiesManager.shouldLogToFile = false
        }
    }

    @objc func domainPreferenceDidChange(_ sender: NSSegmentedControl) {
        PropertiesManager.domainPreference = sender.selectedSegment == 0 ? .domain : .url
        updateDomainPreference(animate: true)
    }

    @objc func segmentedControlDidChange(_ sender: NSSegmentedControl) {
        PropertiesManager.filterType = sender.selectedSegment == 0 ? .denylist : .allowlist
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
            case .denylist:
                PropertiesManager.denylist = textView.string
            case .allowlist:
                PropertiesManager.allowlist = textView.string
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

    func setBrowserVisibility() {
        if MonitoringManager.isMonitoringBrowsing {
            browserLabel.isHidden = false
            domainStackView.isHidden = false
            filterStackView.isHidden = false
        } else {
            browserLabel.isHidden = true
            domainStackView.isHidden = true
            filterStackView.isHidden = true
        }
        adjustWindowSize(animate: false)
    }

    // MARK: State Helpers

    private func updateDomainPreference(animate: Bool) {
        var selectedSegment: Int
        switch PropertiesManager.domainPreference {
            case .domain:
                selectedSegment = 0
            case .url:
                selectedSegment = 1
        }
        domainPreferenceControl.setSelected(true, forSegment: selectedSegment)
        adjustWindowSize(animate: animate)
    }

    private func updateFilterControls(animate: Bool) {
        let denylistTitle = "Denylist:"
        let denylistRemarks =
            "Sites that you don't want to show in your reports. " +
            "Only applicable to browsing activity. One regex per line."
        let allowlistTitle = "Allowlist:"
        let allowlistRemarks =
            "Sites that you want to show in your reports. " +
            "Only applicable to browsing activity. One regex per line."

        var title: String
        var remarks: String
        var list: String
        var selectedSegment: Int
        switch PropertiesManager.filterType {
            case .denylist:
                title = denylistTitle
                remarks = denylistRemarks
                list = PropertiesManager.denylist
                selectedSegment = 0
            case .allowlist:
                title = allowlistTitle
                remarks = allowlistRemarks
                list = PropertiesManager.allowlist
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

        var newWindowFrame = window.frame
        newWindowFrame.size.height = newHeight
        newWindowFrame.origin.y += window.frame.height - newWindowFrame.height // Adjust origin to keep the top-left corner stationary

        window.setFrame(newWindowFrame, display: true, animate: animate)
    }
}
