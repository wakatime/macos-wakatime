import Foundation
import AppKit
import SwiftUI

class MonitoredAppsView: NSView {
    func viewDidLoad() {
        let stackView = NSStackView(frame: .zero)
        stackView.orientation = .vertical
        stackView.distribution = .equalSpacing
        stackView.alignment = .leading

        addSubview(stackView)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32).isActive = true
        stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32).isActive = true
        stackView.topAnchor.constraint(equalTo: topAnchor, constant: 32).isActive = true
        stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -32).isActive = true

        buildView(stackView: stackView)
    }

    func buildView(stackView: NSStackView) {
        for (index, bundleId) in MonitoringManager.appIDsToWatch.enumerated() {
            guard
                let image = AppInfo.getIcon(bundleId: bundleId),
                let appName = AppInfo.getAppName(bundleId: bundleId)
            else { continue }

            let currentStackView = NSStackView(frame: .zero)
            currentStackView.orientation = .horizontal
            currentStackView.distribution = .gravityAreas

            currentStackView.spacing = 32

            let imageView = NSImageView(frame: NSRect(x: 0, y: 0, width: 15, height: 15))
            imageView.image = image
            imageView.layer?.cornerRadius = imageView.frame.height / 2
            currentStackView.addArrangedSubview(imageView)
            currentStackView.setCustomSpacing(8, after: imageView)

            let nameLabel = NSTextField(labelWithString: appName)
            nameLabel.alignment = .left
            let switchControl = NSSwitch()
            switchControl.state = MonitoringManager.isAppMonitored(for: bundleId) ? .on : .off
            switchControl.tag = index
            switchControl.target = self
            switchControl.action = #selector(switchToggled(_:))

            currentStackView.addArrangedSubview(nameLabel)
            currentStackView.addArrangedSubview(switchControl)

            stackView.addArrangedSubview(currentStackView)
            currentStackView.translatesAutoresizingMaskIntoConstraints = false
            currentStackView.leadingAnchor.constraint(equalTo: stackView.leadingAnchor).isActive = true
            currentStackView.trailingAnchor.constraint(equalTo: stackView.trailingAnchor).isActive = true
            currentStackView.huggingPriority(for: .horizontal)
            nameLabel.widthAnchor.constraint(equalTo: currentStackView.widthAnchor, multiplier: 0.7, constant: 0).isActive = true

            let divider = NSView(frame: NSRect(x: 0, y: 0, width: stackView.frame.width, height: 1))
            divider.wantsLayer = true
            divider.layer?.backgroundColor = NSColor.darkGray.cgColor
            divider.translatesAutoresizingMaskIntoConstraints = false
            divider.heightAnchor.constraint(equalToConstant: 1).isActive = true

            stackView.addArrangedSubview(divider)
        }

        stackView.addArrangedSubview(NSView())
    }

    @objc func switchToggled(_ sender: NSSwitch) {
        let index = sender.tag
        let bundleId = MonitoringManager.appIDsToWatch[index]

        MonitoringManager.set(monitoringState: sender.state == .on ? .on : .off, for: bundleId)
    }
}

struct MonitoredAppsViewRepresentable: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = MonitoredAppsView()
        // Configure your NSView here
        view.viewDidLoad()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Update your NSView here
    }
}
