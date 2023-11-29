import Cocoa
import Foundation
import AppKit

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

        /*
        NSEvent.addGlobalMonitorForEvents(
            matching: [NSEvent.EventTypeMask.keyDown],
            handler: handleKeyboardEvent
        )
        */

        /*
        do {
            try EonilFSEvents.startWatching(
                paths: ["/"],
                for: ObjectIdentifier(self),
                with: { event in
                    // NSLog(event)
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

        appVersions[id] = "\(bundle.version)-\(bundle.build)".filter { !$0.isWhitespace }
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
                    NSLog("Setting AXManualAccessibility on \(appName) failed (\(result.rawValue))")
                }
            }

            let observer = try AXObserver.create(appID: app.processIdentifier, callback: observerCallback)
            let this = Unmanaged.passUnretained(self).toOpaque()
            let axApp = AXUIElementCreateApplication(app.processIdentifier)

            try observer.add(notification: kAXFocusedUIElementChangedNotification, element: axApp, refcon: this)
            try observer.add(notification: kAXFocusedWindowChangedNotification, element: axApp, refcon: this)
            try observer.add(notification: kAXSelectedTextChangedNotification, element: axApp, refcon: this)
            if MonitoringManager.isAppElectron(app) {
                try observer.add(notification: kAXValueChangedNotification, element: axApp, refcon: this)
            }

            /*
            if app.monitoredApp == .iterm2 {
                try observer.add(notification: kAXValueChangedNotification, element: axApp, refcon: this)
                try observer.add(notification: kAXMainWindowChangedNotification, element: axApp, refcon: this)
                try observer.add(notification: kAXApplicationActivatedNotification, element: axApp, refcon: this)
                try observer.add(notification: kAXApplicationDeactivatedNotification, element: axApp, refcon: this)
                try observer.add(notification: kAXApplicationHiddenNotification, element: axApp, refcon: this)
                try observer.add(notification: kAXApplicationShownNotification, element: axApp, refcon: this)
                try observer.add(notification: kAXWindowCreatedNotification, element: axApp, refcon: this)
                try observer.add(notification: kAXWindowMovedNotification, element: axApp, refcon: this)
                try observer.add(notification: kAXWindowResizedNotification, element: axApp, refcon: this)
                try observer.add(notification: kAXWindowMiniaturizedNotification, element: axApp, refcon: this)
                try observer.add(notification: kAXWindowDeminiaturizedNotification, element: axApp, refcon: this)
                try observer.add(notification: kAXDrawerCreatedNotification, element: axApp, refcon: this)
                try observer.add(notification: kAXSheetCreatedNotification, element: axApp, refcon: this)
                try observer.add(notification: kAXHelpTagCreatedNotification, element: axApp, refcon: this)
                try observer.add(notification: kAXElementBusyChangedNotification, element: axApp, refcon: this)
                try observer.add(notification: kAXMenuOpenedNotification, element: axApp, refcon: this)
                try observer.add(notification: kAXMenuClosedNotification, element: axApp, refcon: this)
                try observer.add(notification: kAXMenuItemSelectedNotification, element: axApp, refcon: this)
                try observer.add(notification: kAXRowCountChangedNotification, element: axApp, refcon: this)
                try observer.add(notification: kAXRowExpandedNotification, element: axApp, refcon: this)
                try observer.add(notification: kAXRowCollapsedNotification, element: axApp, refcon: this)
                try observer.add(notification: kAXSelectedCellsChangedNotification, element: axApp, refcon: this)
                try observer.add(notification: kAXUnitsChangedNotification, element: axApp, refcon: this)
                try observer.add(notification: kAXSelectedChildrenMovedNotification, element: axApp, refcon: this)
                try observer.add(notification: kAXSelectedChildrenChangedNotification, element: axApp, refcon: this)
                try observer.add(notification: kAXResizedNotification, element: axApp, refcon: this)
                try observer.add(notification: kAXMovedNotification, element: axApp, refcon: this)
                try observer.add(notification: kAXCreatedNotification, element: axApp, refcon: this)
                try observer.add(notification: kAXSelectedRowsChangedNotification, element: axApp, refcon: this)
                try observer.add(notification: kAXSelectedColumnsChangedNotification, element: axApp, refcon: this)
                try observer.add(notification: kAXTitleChangedNotification, element: axApp, refcon: this)
                try observer.add(notification: kAXLayoutChangedNotification, element: axApp, refcon: this)
                try observer.add(notification: kAXAnnouncementRequestedNotification, element: axApp, refcon: this)
            }*/

            observer.addToRunLoop()
            self.observer = observer
            self.observingElement = axApp
            self.statusBarDelegate?.a11yStatusChanged(true)

            if MonitoringManager.isAppXcode(app), let activeWindow = axApp.activeWindow {
                if let currentPath = activeWindow.currentPath {
                    self.documentPath = currentPath
                }
                observeActivityText(activeWindow: activeWindow)
            }
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

            try? observer.remove(notification: kAXFocusedUIElementChangedNotification, element: observingElement)
            try? observer.remove(notification: kAXFocusedWindowChangedNotification, element: observingElement)
            try? observer.remove(notification: kAXSelectedTextChangedNotification, element: observingElement)
            if MonitoringManager.isAppElectron(app) {
                try? observer.remove(notification: kAXValueChangedNotification, element: observingElement)
            }

            self.observingElement = nil
            self.observer = nil
        }
    }

    func observeActivityText(activeWindow: AXUIElement) {
        let this = Unmanaged.passUnretained(self).toOpaque()
        activeWindow.traverseDown { element in
            if let id = element.id, id == "Activity Text" {
                // Remove previously observed "Activity Text" value observer, if any
                if let observingActivityTextElement {
                    try? self.observer?.remove(notification: kAXValueChangedNotification, element: observingActivityTextElement)
                }

                do {
                    // Update the current isBuilding state when the observed "Activity Text" UI element changes
                    self.isBuilding = checkIsBuilding(activityText: element.value)

                    if let path = self.documentPath {
                        self.handleNotificationEvent(path: path, isWrite: false)
                    }

                    // Try to add observer to the current "Activity Text" UI element
                    try self.observer?.add(notification: kAXValueChangedNotification, element: element, refcon: this)
                    observingActivityTextElement = element
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
                entity: path.path,
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

    // print(notification)
    let axNotification = AXUIElementNotification.notificationFrom(string: notification as String)
    switch axNotification {
        case .selectedTextChanged:
            if MonitoringManager.isAppXcode(app) {
                guard
                    !element.selectedText.isEmpty,
                    let currentPath = element.currentPath
                else { return }
                this.heartbeatEventHandler?.handleHeartbeatEvent(
                    app: app,
                    entity: currentPath.path,
                    entityType: EntityType.file,
                    language: nil,
                    category: this.isBuilding ? Category.building : Category.coding,
                    isWrite: false)
            } else {
                if let heartbeat = MonitoringManager.heartbeatData(app, element: element) {
                    this.heartbeatEventHandler?.handleHeartbeatEvent(
                        app: app,
                        entity: heartbeat.entity,
                        entityType: EntityType.app,
                        language: heartbeat.language,
                        category: heartbeat.category,
                        isWrite: false)
                }
            }
        case .focusedUIElementChanged:
            if MonitoringManager.isAppXcode(app) {
                guard let currentPath = element.currentPath else { return }

                this.documentPath = currentPath
            } else {
                if let heartbeat = MonitoringManager.heartbeatData(app, element: element) {
                    this.heartbeatEventHandler?.handleHeartbeatEvent(
                        app: app,
                        entity: heartbeat.entity,
                        entityType: EntityType.app,
                        language: heartbeat.language,
                        category: heartbeat.category,
                        isWrite: false)
                }
            }
        case .focusedWindowChanged:
            if MonitoringManager.isAppXcode(app) {
                this.observeActivityText(activeWindow: element)
            } else {
                if let heartbeat = MonitoringManager.heartbeatData(app, element: element) {
                    this.heartbeatEventHandler?.handleHeartbeatEvent(
                        app: app,
                        entity: heartbeat.entity,
                        entityType: EntityType.app,
                        language: heartbeat.language,
                        category: heartbeat.category,
                        isWrite: false)
                }
            }
        case .valueChanged:
            if MonitoringManager.isAppXcode(app) {
                if let id = element.id, id == "Activity Text" {
                    this.isBuilding = this.checkIsBuilding(activityText: element.value)
                    if let path = this.documentPath {
                        this.handleNotificationEvent(path: path, isWrite: false)
                    }
                }
            } else {
                if let heartbeat = MonitoringManager.heartbeatData(app, element: element) {
                    this.heartbeatEventHandler?.handleHeartbeatEvent(
                        app: app,
                        entity: heartbeat.entity,
                        entityType: EntityType.app,
                        language: heartbeat.language,
                        category: heartbeat.category,
                        isWrite: false)
                }
            }
        default:
            break
    }
}
