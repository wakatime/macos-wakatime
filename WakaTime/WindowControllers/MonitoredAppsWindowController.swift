import AppKit

class MonitoredAppsWindowController: NSWindowController {
    let monitoredAppsView = MonitoredAppsView()

    convenience init() {
        self.init(window: nil)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 450),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Monitored Apps"
        window.contentView = monitoredAppsView
        self.window = window
    }

    override func showWindow(_ sender: Any?) {
        monitoredAppsView.reloadData()
        super.showWindow(sender)
    }
}
