import AppUpdater
import Cocoa
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, StatusBarDelegate {
    var window: NSWindow!
    var statusBarItem: NSStatusItem!
    var statusBarA11yItem: NSMenuItem!
    var statusBarA11ySeparator: NSMenuItem!
    var statusBarA11yStatus: Bool = true
    var settingsWindowController = SettingsWindowController()
    var monitoredAppsWindowController = MonitoredAppsWindowController()
    var wakaTime: WakaTime?

    let updater = AppUpdater(owner: "wakatime", repo: "macos-wakatime")

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Configure logging to a log file if activated by the user
        if PropertiesManager.shouldLogToFile {
            Logging.default.activateLoggingToFile()
        }

        Logging.default.log("Starting WakaTime")

        // Handle deep links
        let eventManager = NSAppleEventManager.shared()
        eventManager.setEventHandler(
            self,
            andSelector: #selector(handleGetURL(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL)
        )

        let statusBar = NSStatusBar.system
        statusBarItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        statusBarItem.button?.image = NSImage(named: NSImage.Name("WakaTime"))

        let menu = NSMenu()

        statusBarA11yItem = NSMenuItem(
            title: "* A11y permission needed *",
            action: #selector(AppDelegate.a11yClicked(_:)),
            keyEquivalent: "")
        statusBarA11yItem.isHidden = true
        menu.addItem(statusBarA11yItem)
        statusBarA11ySeparator = NSMenuItem.separator()
        menu.addItem(statusBarA11ySeparator)
        statusBarA11ySeparator.isHidden = true
        menu.addItem(withTitle: "Dashboard", action: #selector(AppDelegate.dashboardClicked(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Settings", action: #selector(AppDelegate.settingsClicked(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Monitored Apps", action: #selector(AppDelegate.monitoredAppsClicked(_:)), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Check for Updates", action: #selector(AppDelegate.checkForUpdatesClicked(_:)), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit", action: #selector(AppDelegate.quitClicked(_:)), keyEquivalent: "")

        statusBarItem.menu = menu

        wakaTime = WakaTime(self)

        // request notifications permission
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            guard granted else {
                if let msg = error?.localizedDescription {
                    Logging.default.log(msg)
                }
                return
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        Logging.default.log("WakaTime will terminate")
    }

    @objc func handleGetURL(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        // Handle deep links
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString),
              url.scheme == "wakatime",
              let link = DeepLink(rawValue: url.host ?? "")
        else { return }

        switch link {
            case .settings:
                showSettings()
            case .monitoredApps:
                showMonitoredApps()
        }
    }

    @objc func dashboardClicked(_ sender: AnyObject) {
        if let url = URL(string: "https://wakatime.com/") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func settingsClicked(_ sender: AnyObject) {
        showSettings()
    }

    @objc func monitoredAppsClicked(_ sender: AnyObject) {
        showMonitoredApps()
    }

    @objc func checkForUpdatesClicked(_ sender: AnyObject) {
        updater.check {
            self.toastNotification("Updating to latest release")
        }.catch(policy: .allErrors) { error in
            if error.isCancelled {
                let alert = NSAlert()
                alert.messageText = "Up to date"
                alert.informativeText = "You have the latest version (\(Bundle.main.version))."
                alert.alertStyle = NSAlert.Style.warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            } else {
                Logging.default.log(String(describing: error))
                let alert = NSAlert()
                alert.messageText = "Error"
                let max = 200
                if error.localizedDescription.count <= max {
                    alert.informativeText = error.localizedDescription
                } else {
                    alert.informativeText = String(error.localizedDescription.prefix(max).appending("…"))
                }
                alert.alertStyle = NSAlert.Style.warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }

    @objc func a11yClicked(_ sender: AnyObject) {
        a11yStatusChanged(Accessibility.requestA11yPermission())
    }

    @objc func quitClicked(_ sender: AnyObject) {
        NSApplication.shared.terminate(self)
    }

    func a11yStatusChanged(_ hasPermission: Bool) {
        guard statusBarA11yStatus != hasPermission else { return }

        statusBarA11yStatus = hasPermission
        if hasPermission {
            statusBarItem.button?.image = NSImage(named: NSImage.Name("WakaTime"))
        } else {
            statusBarItem.button?.image = NSImage(named: NSImage.Name("WakaTimeDisabled"))
        }
        statusBarA11yItem.isHidden = hasPermission
        statusBarA11ySeparator.isHidden = hasPermission
    }

    private func showSettings() {
        NSApp.activate(ignoringOtherApps: true)
        settingsWindowController.settingsView.setBrowserVisibility()
        settingsWindowController.showWindow(self)
    }

    private func showMonitoredApps() {
        NSApp.activate(ignoringOtherApps: true)
        monitoredAppsWindowController.showWindow(self)
    }

    internal func toastNotification(_ title: String) {
        let content = UNMutableNotificationContent()
        content.title = title

        let uuidString = UUID().uuidString
        let request = UNNotificationRequest(
        identifier: uuidString,
        content: content, trigger: nil)

        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }

            notificationCenter.add(request)
        }
    }
}
