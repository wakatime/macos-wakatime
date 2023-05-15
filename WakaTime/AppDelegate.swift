import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var statusBarItem: NSStatusItem!
    var settingsWindowController = SettingsWindowController()
    var wakaTime: WakaTime?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        wakaTime = WakaTime()

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

        menu.addItem(withTitle: "Dashboard", action: #selector(AppDelegate.dashboardClicked(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Settings", action: #selector(AppDelegate.settingsClicked(_:)), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit", action: #selector(AppDelegate.quitClicked(_:)), keyEquivalent: "")

        statusBarItem.menu = menu
    }

    @objc func handleGetURL(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        // Handle deep links
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString),
              url.scheme == "wakatime"
        else { return }

        if url.host == "settings" {
            showSettings()
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

    @objc func quitClicked(_ sender: AnyObject) {
        NSApplication.shared.terminate(self)
    }

    private func showSettings() {
        NSApp.activate(ignoringOtherApps: true)
        settingsWindowController.showWindow(self)
    }
}
