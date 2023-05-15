import Foundation
import AppKit

class SettingsWindowController: NSWindowController, NSTextFieldDelegate {
    var apiKey: String = ""
    var textField: NSTextField?

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
        self.window = window

        let contentView = NSView()
        window.contentView = contentView

        let apiKeyLabel = NSTextField(labelWithString: "WakaTime API Key:")
        apiKeyLabel.frame = NSRect(x: 20, y: 110, width: 200, height: 20)
        contentView.addSubview(apiKeyLabel)

        textField = NSTextField(frame: NSRect(x: 20, y: 80, width: 360, height: 20))
        if let textField {
            textField.stringValue = ConfigFile.getSetting(section: "settings", key: "api_key") ?? ""
            textField.delegate = self
            contentView.addSubview(textField)
        }

        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveButtonClicked))
        saveButton.frame = NSRect(x: 10, y: 40, width: 80, height: 40)
        saveButton.keyEquivalent = "\r"
        window.defaultButtonCell = saveButton.cell as? NSButtonCell
        contentView.addSubview(saveButton)

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelButtonClicked))
        cancelButton.frame = NSRect(x: 80, y: 40, width: 80, height: 40)
        cancelButton.keyEquivalent = "\u{1b}"
        contentView.addSubview(cancelButton)

        let versionString = "Version: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")"
            + "(\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""))"
        let versionLabel = NSTextField(labelWithString: versionString)
        versionLabel.frame = NSRect(x: 20, y: 20, width: 360, height: 20)
        contentView.addSubview(versionLabel)
    }

    @objc func saveButtonClicked() {
        if let text = textField?.stringValue {
            ConfigFile.setSetting(section: "settings", key: "api_key", val: text)
        }
        self.window?.close()
    }

    @objc func cancelButtonClicked() {
        self.window?.close()
    }

    func controlTextDidChange(_ obj: Notification) {
        apiKey = textField?.stringValue ?? ""
    }
}
