import Cocoa
import Foundation
import AppKit

class Watcher: NSObject {
    private let callbackQueue = DispatchQueue(label: "com.WakaTime.Watcher.callbackQueue", qos: .utility)
    private let monitorQueue = DispatchQueue(label: "com.WakaTime.Watcher.monitorQueue", qos: .utility)

    var appVersions: [String: String] = [:]
    var eventSourceObserver: EventSourceObserver?
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
    private var lastValidHeartbeatForApp = [String: HeartbeatData]()

    override init() {
        super.init()

        eventSourceObserver = EventSourceObserver(pollIntervalInSeconds: 1)

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appChanged),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        if let app = NSWorkspace.shared.frontmostApplication {
            handleAppChanged(app)
        }
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
            // swiftlint:disable line_length
            Logging.default.log("App changed from \(activeApp?.localizedName ?? "nil") to \(app.localizedName ?? "nil") (\(app.bundleIdentifier ?? "nil"))")
            eventSourceObserver?.stop()
            // swiftlint:enable line_length
            if let oldApp = activeApp { unwatch(app: oldApp) }
            activeApp = app
            if let bundleId = app.bundleIdentifier, MonitoringManager.isAppMonitored(for: bundleId) {
                watch(app: app)
            }
        }

        setAppVersion(app)
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
                    Logging.default.log("Setting AXManualAccessibility on \(appName) failed (\(result.rawValue))")
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

            observer.addToRunLoop()
            self.observer = observer
            self.observingElement = axApp
            self.statusBarDelegate?.a11yStatusChanged(true)

            if MonitoringManager.isAppXcode(app), let activeWindow = axApp.activeWindow {
                if let currentPath = activeWindow.currentPath {
                    self.documentPath = currentPath
                }
                observeActivityText(activeWindow: activeWindow)
            } else {
                eventSourceObserver?.start { [weak self] in
                    self?.callbackQueue.async {
                        guard
                            let app = self?.activeApp, !MonitoringManager.isAppXcode(app),
                            let bundleId = app.bundleIdentifier
                        else { return }

                        var heartbeat = MonitoringManager.heartbeatData(app)

                        if let heartbeat {
                            self?.lastValidHeartbeatForApp[bundleId] = heartbeat
                        } else {
                            heartbeat = self?.lastValidHeartbeatForApp[bundleId]
                        }

                        if let heartbeat {
                            self?.heartbeatEventHandler?.handleHeartbeatEvent(
                                app: app,
                                entity: heartbeat.entity,
                                entityType: EntityType.app,
                                project: heartbeat.project,
                                language: heartbeat.language,
                                category: heartbeat.category,
                                isWrite: false
                            )
                        }
                    }
                }
            }
        } catch {
            Logging.default.log("Failed to setup AXObserver: \(error.localizedDescription)")

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

                Logging.default.log("Document changed: \(newPath)")

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
                project: nil,
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
                    project: nil,
                    language: nil,
                    category: this.isBuilding ? Category.building : Category.coding,
                    isWrite: false)
            }
        case .focusedUIElementChanged:
            if MonitoringManager.isAppXcode(app) {
                guard let currentPath = element.currentPath else { return }

                this.documentPath = currentPath
            }
        case .focusedWindowChanged:
            if MonitoringManager.isAppXcode(app) {
                this.observeActivityText(activeWindow: element)
            }
        case .valueChanged:
            if MonitoringManager.isAppXcode(app) {
                if let id = element.id, id == "Activity Text" {
                    this.isBuilding = this.checkIsBuilding(activityText: element.value)
                    if let path = this.documentPath {
                        this.handleNotificationEvent(path: path, isWrite: false)
                    }
                }
            }
        default:
            break
    }
}
