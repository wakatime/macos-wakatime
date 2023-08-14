import Cocoa
import Foundation
import AppKit

// swiftlint:disable force_cast
class Watcher: NSObject {
    private let callbackQueue = DispatchQueue(label: "com.WakaTime.Watcher.callbackQueue", qos: .utility)
    private let monitorQueue = DispatchQueue(label: "com.WakaTime.Watcher.monitorQueue", qos: .utility)

    var appVersions: [String: String] = [:]
    var heartbeatEventHandler: HeartbeatEventHandler?
    var statusBarDelegate: StatusBarDelegate?
    var lastCheckedA11y = Date()
    var isBuilding = false
    var activeApp: NSRunningApplication?
    private var observer: AXObserver?
    private var observingElement: AXUIElement?
    private var observingActivityTextElement: AXUIElement?
    private var fileMonitor: FileMonitor?
    private var selectedText: String?

    override init() {
        super.init()

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appChanged),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        if let app = NSWorkspace.shared.frontmostApplication {
            handleAppChanged(app)
        }

        NSEvent.addGlobalMonitorForEvents(
            matching: [NSEvent.EventTypeMask.keyDown],
            handler: handleKeyboardEvent
        )

        /*
        do {
            try EonilFSEvents.startWatching(
                paths: ["/"],
                for: ObjectIdentifier(self),
                with: { event in
                    // print(event)
                }
            )
        } catch {
            NSLog("Failed to setup FSEvents: \(error.localizedDescription)")
        }
        */
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self) // needed prior macOS 11 only
    }

    @objc private func appChanged(_ notification: Notification) {
        guard let newApp = notification.userInfo?["NSWorkspaceApplicationKey"] as? NSRunningApplication else { return }

        handleAppChanged(newApp)
    }

    private func handleAppChanged(_ app: NSRunningApplication) {
        if app != activeApp {
            NSLog("App changed from \(activeApp?.localizedName ?? "nil") to \(app.localizedName ?? "nil")")
            if let oldApp = activeApp { unwatch(app: oldApp) }
            activeApp = app
            if let bundleId = app.bundleIdentifier, MonitoringManager.isAppMonitored(for: bundleId) {
                watch(app: app)
            }
        }

        setAppVersion(app)
    }

    func handleKeyboardEvent(event: NSEvent!) {
        // NSLog("keyDown")
        // TODO: call eventHandler to send heartbeat
    }

    private func setAppVersion(_ app: NSRunningApplication) {
        guard
            let id = app.bundleIdentifier,
            appVersions[id] == nil,
            let url = app.bundleURL,
            let bundle = Bundle(url: url)
        else { return }

        let version = "\(bundle.version)-\(bundle.build)"
        appVersions[id] = version
    }

    public func getAppVersion(_ app: NSRunningApplication) -> String? {
        guard let id = app.bundleIdentifier else { return nil }
        return appVersions[id]
    }

    private func watch(app: NSRunningApplication) {
        setAppVersion(app)

        do {
            if MonitoringManager.isAppElectron(app) {
                let pid = app.processIdentifier
                let axApp = AXUIElementCreateApplication(pid)
                let result = AXUIElementSetAttributeValue(axApp, "AXManualAccessibility" as CFString, true as CFTypeRef)
                if result.rawValue != 0 {
                    let appName = app.localizedName ?? "UnknownApp"
                    print("Setting AXManualAccessibility on \(appName) failed (\(result.rawValue))")
                    NSLog("Setting AXManualAccessibility on \(appName) failed (\(result.rawValue))")
                }
            }

            let observer = try AXObserver.create(appID: app.processIdentifier, callback: observerCallback)
            let this = Unmanaged.passUnretained(self).toOpaque()
            let element = AXUIElementCreateApplication(app.processIdentifier)

            try observer.add(notification: kAXFocusedUIElementChangedNotification, element: element, refcon: this)
            try observer.add(notification: kAXFocusedWindowChangedNotification, element: element, refcon: this)
            try observer.add(notification: kAXSelectedTextChangedNotification, element: element, refcon: this)

            if MonitoringManager.isAppElectron(app) {
                try observer.add(notification: kAXValueChangedNotification, element: element, refcon: this)
                try observer.add(notification: kAXMainWindowChangedNotification, element: element, refcon: this)
                try observer.add(notification: kAXApplicationActivatedNotification, element: element, refcon: this)
                try observer.add(notification: kAXApplicationDeactivatedNotification, element: element, refcon: this)
                try observer.add(notification: kAXApplicationHiddenNotification, element: element, refcon: this)
                try observer.add(notification: kAXApplicationShownNotification, element: element, refcon: this)
                try observer.add(notification: kAXWindowCreatedNotification, element: element, refcon: this)
                try observer.add(notification: kAXWindowMovedNotification, element: element, refcon: this)
                try observer.add(notification: kAXWindowResizedNotification, element: element, refcon: this)
                try observer.add(notification: kAXWindowMiniaturizedNotification, element: element, refcon: this)
                try observer.add(notification: kAXWindowDeminiaturizedNotification, element: element, refcon: this)
                try observer.add(notification: kAXDrawerCreatedNotification, element: element, refcon: this)
                try observer.add(notification: kAXSheetCreatedNotification, element: element, refcon: this)
                try observer.add(notification: kAXHelpTagCreatedNotification, element: element, refcon: this)
                try observer.add(notification: kAXElementBusyChangedNotification, element: element, refcon: this)
                try observer.add(notification: kAXMenuOpenedNotification, element: element, refcon: this)
                try observer.add(notification: kAXMenuClosedNotification, element: element, refcon: this)
                try observer.add(notification: kAXMenuItemSelectedNotification, element: element, refcon: this)
                try observer.add(notification: kAXRowCountChangedNotification, element: element, refcon: this)
                try observer.add(notification: kAXRowExpandedNotification, element: element, refcon: this)
                try observer.add(notification: kAXRowCollapsedNotification, element: element, refcon: this)
                try observer.add(notification: kAXSelectedCellsChangedNotification, element: element, refcon: this)
                try observer.add(notification: kAXUnitsChangedNotification, element: element, refcon: this)
                try observer.add(notification: kAXSelectedChildrenMovedNotification, element: element, refcon: this)
                try observer.add(notification: kAXSelectedChildrenChangedNotification, element: element, refcon: this)
                try observer.add(notification: kAXResizedNotification, element: element, refcon: this)
                try observer.add(notification: kAXMovedNotification, element: element, refcon: this)
                try observer.add(notification: kAXCreatedNotification, element: element, refcon: this)
                try observer.add(notification: kAXSelectedRowsChangedNotification, element: element, refcon: this)
                try observer.add(notification: kAXSelectedColumnsChangedNotification, element: element, refcon: this)
                try observer.add(notification: kAXTitleChangedNotification, element: element, refcon: this)
                try observer.add(notification: kAXLayoutChangedNotification, element: element, refcon: this)
                try observer.add(notification: kAXAnnouncementRequestedNotification, element: element, refcon: this)
            }

            observer.addToRunLoop()
            self.observer = observer
            self.observingElement = element
            if let activeWindow = element.getValue(for: kAXFocusedWindowAttribute) {
                let activeWindow = activeWindow as! AXUIElement
                if let currentPath = getCurrentPath(window: activeWindow, refcon: this) {
                    self.documentPath = currentPath
                }
                observeActivityText(activeWindow: activeWindow)
            }
            // NSLog("Watching for file changes on \(app.localizedName ?? "nil")")
            self.statusBarDelegate?.a11yStatusChanged(true)
        } catch {
            NSLog("Failed to setup AXObserver: \(error.localizedDescription)")

            // TODO: App could be still launching, retry setting AXObserver in 20 seconds for this app

            if lastCheckedA11y.timeIntervalSinceNow > 60 {
                lastCheckedA11y = Date()
                self.statusBarDelegate?.a11yStatusChanged(Accessibility.requestA11yPermission())
            }
        }
    }

    private func unwatch(app: NSRunningApplication) {
        if let observer {
            observer.removeFromRunLoop()
            guard let observingElement else { fatalError("observingElement should not be nil here") }

            try? observer.remove(notification: kAXMainWindowChangedNotification, element: observingElement)
            try? observer.remove(notification: kAXFocusedWindowChangedNotification, element: observingElement)
            try? observer.remove(notification: kAXFocusedUIElementChangedNotification, element: observingElement)
            try? observer.remove(notification: kAXApplicationActivatedNotification, element: observingElement)
            try? observer.remove(notification: kAXApplicationDeactivatedNotification, element: observingElement)
            try? observer.remove(notification: kAXApplicationHiddenNotification, element: observingElement)
            try? observer.remove(notification: kAXApplicationShownNotification, element: observingElement)
            try? observer.remove(notification: kAXWindowCreatedNotification, element: observingElement)
            try? observer.remove(notification: kAXWindowMovedNotification, element: observingElement)
            try? observer.remove(notification: kAXWindowResizedNotification, element: observingElement)
            try? observer.remove(notification: kAXWindowMiniaturizedNotification, element: observingElement)
            try? observer.remove(notification: kAXWindowDeminiaturizedNotification, element: observingElement)
            try? observer.remove(notification: kAXDrawerCreatedNotification, element: observingElement)
            try? observer.remove(notification: kAXSheetCreatedNotification, element: observingElement)
            try? observer.remove(notification: kAXHelpTagCreatedNotification, element: observingElement)
            try? observer.remove(notification: kAXValueChangedNotification, element: observingElement)
            try? observer.remove(notification: kAXElementBusyChangedNotification, element: observingElement)
            try? observer.remove(notification: kAXMenuOpenedNotification, element: observingElement)
            try? observer.remove(notification: kAXMenuClosedNotification, element: observingElement)
            try? observer.remove(notification: kAXMenuItemSelectedNotification, element: observingElement)
            try? observer.remove(notification: kAXRowCountChangedNotification, element: observingElement)
            try? observer.remove(notification: kAXRowExpandedNotification, element: observingElement)
            try? observer.remove(notification: kAXRowCollapsedNotification, element: observingElement)
            try? observer.remove(notification: kAXSelectedCellsChangedNotification, element: observingElement)
            try? observer.remove(notification: kAXUnitsChangedNotification, element: observingElement)
            try? observer.remove(notification: kAXSelectedChildrenMovedNotification, element: observingElement)
            try? observer.remove(notification: kAXSelectedChildrenChangedNotification, element: observingElement)
            try? observer.remove(notification: kAXResizedNotification, element: observingElement)
            try? observer.remove(notification: kAXMovedNotification, element: observingElement)
            try? observer.remove(notification: kAXCreatedNotification, element: observingElement)
            try? observer.remove(notification: kAXSelectedRowsChangedNotification, element: observingElement)
            try? observer.remove(notification: kAXSelectedColumnsChangedNotification, element: observingElement)
            try? observer.remove(notification: kAXSelectedTextChangedNotification, element: observingElement)
            try? observer.remove(notification: kAXTitleChangedNotification, element: observingElement)
            try? observer.remove(notification: kAXLayoutChangedNotification, element: observingElement)
            try? observer.remove(notification: kAXAnnouncementRequestedNotification, element: observingElement)

            self.observingElement = nil
            self.observer = nil
            // NSLog("Stopped watching \(app.localizedName ?? "nil")")
        }
    }

    func observeActivityText(activeWindow: AXUIElement) {
        let this = Unmanaged.passUnretained(self).toOpaque()
        activeWindow.traverse { element in
            let id = element.getValue(for: kAXIdentifierAttribute) as? String
            if id == "Activity Text" {
                // Remove previously observed "Activity Text" value observer, if any
                if let observingActivityTextElement {
                    try? self.observer?.remove(notification: kAXValueChangedNotification, element: observingActivityTextElement)
                }
                do {
                    // Try to add observer to the current "Activity Text" UI element
                    try self.observer?.add(notification: kAXValueChangedNotification, element: element, refcon: this)
                    observingActivityTextElement = element
                    // Update the current isBuilding state when the observed "Activity Text" UI element changes
                    let value = element.getValue(for: kAXValueAttribute) as? String
                    self.isBuilding = checkIsBuilding(activityText: value)
                    if let path = self.documentPath {
                        self.handleNotificationEvent(path: path, isWrite: false)
                    }
                } catch {
                    observingActivityTextElement = nil
                }
                return false // "Activity Text" element found, abort traversal
            }
            return true // continue traversal
        }
    }

    func checkIsBuilding(activityText: String?) -> Bool {
        activityText == "Build" || (activityText?.contains("Building") == true)
    }

    var documentPath: URL? {
        didSet {
            if documentPath != oldValue {
                guard let newPath = documentPath else { return }

                NSLog("Document changed: \(newPath)")

                handleNotificationEvent(path: newPath, isWrite: false)
                fileMonitor = nil
                fileMonitor = FileMonitor(filePath: newPath, queue: monitorQueue)
                fileMonitor?.fileChangedEventHandler = { [weak self] in
                    self?.handleNotificationEvent(path: newPath, isWrite: true)
                }
            }
        }
    }

    public func handleNotificationEvent(path: URL, isWrite: Bool) {
        callbackQueue.async {
            guard let app = self.activeApp else { return }

            self.heartbeatEventHandler?.handleHeartbeatEvent(
                app: app,
                entity: path.formatted(),
                entityType: EntityType.file,
                language: nil,
                category: self.isBuilding ? Category.building : Category.coding,
                isWrite: isWrite
            )
        }
    }
}

private func observerCallback(
    _ observer: AXObserver,
    _ element: AXUIElement,
    _ notification: CFString,
    _ refcon: UnsafeMutableRawPointer?
) {
    guard let refcon = refcon else { return }

    let this = Unmanaged<Watcher>.fromOpaque(refcon).takeUnretainedValue()

    guard let app = this.activeApp else { return }

    if MonitoringManager.isAppElectron(app) {
        // print(notification)
        if let heartbeat = MonitoringManager.heartbeatData(app, element: element) {
            this.heartbeatEventHandler?.handleHeartbeatEvent(
                app: app,
                entity: heartbeat.entity,
                entityType: EntityType.app,
                language: heartbeat.language,
                category: heartbeat.category,
                isWrite: false)
        }
        return
    }

    let axNotification = AXUIElementNotification.notificationFrom(string: notification as String)
    switch axNotification {
        case .selectedTextChanged:
            guard
                !element.selectedText.isEmpty,
                let currentPath = getCurrentPath(element: element, refcon: refcon)
            else { return }
            this.heartbeatEventHandler?.handleHeartbeatEvent(
                app: app,
                entity: currentPath.formatted(),
                entityType: EntityType.file,
                language: nil,
                category: this.isBuilding ? Category.building : Category.coding,
                isWrite: false)
        case .focusedUIElementChanged:
            guard let currentPath = getCurrentPath(element: element, refcon: refcon) else { return }
            this.documentPath = currentPath
        case .focusedWindowChanged:
            this.observeActivityText(activeWindow: element)
        case .valueChanged:
            let id = element.getValue(for: kAXIdentifierAttribute) as? String
            let value = element.getValue(for: kAXValueAttribute) as? String
            if let id, id == "Activity Text" {
                this.isBuilding = this.checkIsBuilding(activityText: value)
                if let path = this.documentPath {
                    this.handleNotificationEvent(path: path, isWrite: false)
                }
            }
        default:
            break
    }
}

private func getCurrentPath(element: AXUIElement, refcon: UnsafeMutableRawPointer?) -> URL? {
    if let window = element.getValue(for: kAXWindowAttribute) {
        return getCurrentPath(window: (window as! AXUIElement), refcon: refcon)
    }
    return nil
}

private func getCurrentPath(window: AXUIElement, refcon: UnsafeMutableRawPointer?) -> URL? {
    guard CFGetTypeID(window) == AXUIElementGetTypeID() else { return nil }

    if var path = window.getValue(for: kAXDocumentAttribute) as? String {
        if path.hasPrefix("file://") {
            path = path.dropFirst(7).description
        }
        return URL(string: path)
    }

    return nil
}
// swiftlint:enable force_cast
