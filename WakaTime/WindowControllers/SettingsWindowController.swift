import AppKit

class SettingsWindowController: NSWindowController, NSTextFieldDelegate {
    let settingsView = SettingsView()

    convenience init() {
        self.init(window: nil)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 150),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Settings"
        window.contentView = settingsView
        self.window = window
    }
}
