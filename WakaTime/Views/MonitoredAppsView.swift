import AppKit

class MonitoredAppsView: NSView, NSOutlineViewDataSource, NSOutlineViewDelegate {
    struct AppData: Equatable {
        let bundleId: String
        let icon: NSImage
        let name: String
        let tag: Int
    }

    private var outlineView: NSOutlineView!

    private lazy var apps: [AppData] = {
        var apps = [AppData]()
        let bundleIds = sort(MonitoredApp.allBundleIds + runningApps())
        var index = 0
        for bundleId in bundleIds {
            if let icon = AppInfo.getIcon(bundleId: bundleId),
               let name = AppInfo.getAppName(bundleId: bundleId) {
                apps.append(AppData(bundleId: bundleId, icon: icon, name: name, tag: index))
                index += 1
            }

            let setAppBundleId = bundleId.appending("-setapp")
            if let icon = AppInfo.getIcon(bundleId: setAppBundleId),
               let name = AppInfo.getAppName(bundleId: setAppBundleId) {
                apps.append(AppData(bundleId: setAppBundleId, icon: icon, name: name, tag: index))
                index += 1
            }
        }
        return apps
    }()

    private func runningApps() -> [String] {
        var ids: [String] = []
        for runningApp in NSWorkspace.shared.runningApplications where runningApp.activationPolicy == .regular {
            guard let id = runningApp.bundleIdentifier else { continue }

            let bundleId = id.replacingOccurrences(of: "-setapp$", with: "", options: .regularExpression)

            guard
                !MonitoredApp.unsupportedAppIds.contains(where: { $0 == bundleId }),
                !MonitoredApp.allBundleIds.contains(where: { $0 == bundleId })
            else { continue }

            ids.append(bundleId)
        }
        return ids
    }

    private func sort(_ bundleIds: [String]) -> [String] {
        bundleIds.sorted {
            let left = AppInfo.getAppName(bundleId: $0) ?? $0
            let right = AppInfo.getAppName(bundleId: $1) ?? $1
            return left.localizedCaseInsensitiveCompare(right) == ComparisonResult.orderedAscending
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        setupOutlineView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupOutlineView() {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        outlineView = NSOutlineView()
        outlineView.dataSource = self
        outlineView.delegate = self

        scrollView.documentView = outlineView
        addSubview(scrollView)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("AppColumn"))
        outlineView.addTableColumn(column)
        outlineView.headerView = nil
        outlineView.outlineTableColumn = column
        outlineView.indentationPerLevel = 0.0
    }

    func reloadData() {
        outlineView.reloadData()
    }

    // MARK: NSOutlineViewDataSource

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        apps.count
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        false
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        apps[index]
    }

    // MARK: NSOutlineViewDelegate

    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        false
    }

    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        50
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let appData = item as? AppData else { return nil }

        let cellView = outlineView.makeView(
          withIdentifier: NSUserInterfaceItemIdentifier("AppCell"),
          owner: self
        ) as? NSTableCellView ?? NSTableCellView()

        // Clear existing subviews to prevent duplication
        cellView.subviews.forEach { $0.removeFromSuperview() }

        let imageView = NSImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = appData.icon
        imageView.image?.size = NSSize(width: 20, height: 20)

        let nameLabel = NSTextField(labelWithString: appData.name)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        let action = switchOrLink(appData)

        cellView.addSubview(imageView)
        cellView.addSubview(nameLabel)
        cellView.addSubview(action)

        // Determine if the current item is the last in the list
        let isLastItem = apps.last == appData

        if !isLastItem {
            let divider = NSView()
            divider.translatesAutoresizingMaskIntoConstraints = false
            divider.wantsLayer = true
            divider.layer?.backgroundColor = NSColor.separatorColor.cgColor

            cellView.addSubview(divider)

            NSLayoutConstraint.activate([
                divider.heightAnchor.constraint(equalToConstant: 1),
                divider.leadingAnchor.constraint(equalTo: cellView.leadingAnchor),
                divider.trailingAnchor.constraint(equalTo: cellView.trailingAnchor),
                divider.bottomAnchor.constraint(equalTo: cellView.bottomAnchor)
            ])
        }

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 5),
            imageView.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 20),
            imageView.heightAnchor.constraint(equalToConstant: 20),

            nameLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 10),
            nameLabel.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: action.leadingAnchor, constant: -5),

            action.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -10),
            action.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
        ])

        return cellView
    }

    func switchOrLink(_ appData: AppData) -> NSView {
        if MonitoredApp.pluginAppIds[appData.bundleId] != nil {
            let button = NSButton()
            button.translatesAutoresizingMaskIntoConstraints = false
            button.bezelStyle = NSButton.BezelStyle.rounded
            button.title = "Install plugin"
            button.action = #selector(clickInstallPlugin(_:))
            button.widthAnchor.constraint(equalToConstant: 100).isActive = true
            button.tag = appData.tag
            return button
        }

        let isMonitored = MonitoringManager.isAppMonitored(for: appData.bundleId)
        let switchControl = NSSwitch()
        switchControl.translatesAutoresizingMaskIntoConstraints = false
        switchControl.state = isMonitored ? .on : .off
        switchControl.target = self
        switchControl.action = #selector(switchToggled(_:))
        switchControl.tag = appData.tag
        return switchControl
    }

    @objc func switchToggled(_ sender: NSSwitch) {
        let appData = apps[sender.tag]
        MonitoringManager.set(monitoringState: sender.state == .on ? .on : .off, for: appData.bundleId)
    }

    @objc func clickInstallPlugin(_ sender: NSButton) {
        let appData = apps[sender.tag]
        guard
            let path = MonitoredApp.pluginAppIds[appData.bundleId],
            let url = URL(string: "https://wakatime.com/\(path)")
        else { return }

        NSWorkspace.shared.open(url)
    }
}
