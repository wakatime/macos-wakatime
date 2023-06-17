import Foundation
import AppKit

// swiftlint:disable force_cast
class Watcher: NSObject {
    private let callbackQueue = DispatchQueue(label: "com.WakaTime.Watcher.callbackQueue", qos: .utility)
    private let monitorQueue = DispatchQueue(label: "com.WakaTime.Watcher.monitorQueue", qos: .utility)

    var appVersions: [String: String] = [:]
    var eventHandler: ((_ app: NSRunningApplication, _ path: URL, _ isWrite: Bool, _ isBuilding: Bool) -> Void)?
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
            if let newAppID = app.bundleIdentifier, MonitoringManager.isAppMonitored(for: newAppID) {
                watch(app: app)
            } else if let oldApp = activeApp {
                unwatch(app: oldApp)
            }
            activeApp = app
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
            let observer = try AXObserver.create(appID: app.processIdentifier, callback: observerCallback)
            let this = Unmanaged.passUnretained(self).toOpaque()
            let element = AXUIElementCreateApplication(app.processIdentifier)
            try observer.add(notification: kAXFocusedUIElementChangedNotification, element: element, refcon: this)
            try observer.add(notification: kAXFocusedWindowChangedNotification, element: element, refcon: this)
            try observer.add(notification: kAXSelectedTextChangedNotification, element: element, refcon: this)
            observer.addToRunLoop()
            self.observer = observer
            self.observingElement = element
            let activeWindow = element.getValue(for: kAXFocusedWindowAttribute) as! AXUIElement
            if let currentPath = getCurrentPath(window: activeWindow, refcon: this) {
                self.documentPath = currentPath
            }
            observeActivityText(activeWindow: activeWindow)
            // NSLog("Watching for file changes on \(app.localizedName ?? "nil")")
        } catch {
            NSLog("Failed to setup AXObserver: \(error.localizedDescription)")
        }
    }

    private func unwatch(app: NSRunningApplication) {
        if let observer {
            observer.removeFromRunLoop()
            guard let observingElement else { fatalError("observingElement should not be nil here") }

            try? observer.remove(notification: kAXFocusedUIElementChangedNotification, element: observingElement)
            try? observer.remove(notification: kAXSelectedTextChangedNotification, element: observingElement)
            try? observer.remove(notification: kAXValueChangedNotification, element: observingElement)
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

            self.eventHandler?(app, path, isWrite, self.isBuilding)
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

    let axNotification = AXUIElementNotification.notificationFrom(string: notification as String)
    let this = Unmanaged<Watcher>.fromOpaque(refcon).takeUnretainedValue()

    guard let app = this.activeApp else { return }

    switch axNotification {
        case .selectedTextChanged:
            guard
                let currentPath = getCurrentPath(element: element, refcon: refcon),
                !element.selectedText.isEmpty
            else { return }
            this.eventHandler?(app, currentPath, false, this.isBuilding)
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

extension AXObserver {
    static func create(appID: pid_t, callback: AXObserverCallback) throws -> AXObserver {
        var observer: AXObserver?
        let error = AXObserverCreate(appID, callback, &observer)

        guard error == .success else { throw AXObserverError.createFailed(error) }
        guard let observer else { throw AXObserverError.createFailed(error) }

        return observer
    }

    func add(notification: String, element: AXUIElement, refcon: UnsafeMutableRawPointer?) throws {
        let error = AXObserverAddNotification(self, element, notification as CFString, refcon)
        guard error == .success else {
            NSLog("Add notification \(notification) failed: \(error.rawValue)")
            throw AXObserverError.addNotificationFailed(error)
        }

        // NSLog("Added notification \(notification) to observer \(self)")
    }

    func remove(notification: String, element: AXUIElement) throws {
        let error = AXObserverRemoveNotification(self, element, notification as CFString)
        guard error == .success else {
            NSLog("Remove notification \(notification) failed: \(error.rawValue)")
            throw AXObserverError.removeNotificationFailed(error)
        }

        // NSLog("Removed notification \(notification) from observer \(self)")
    }

    func addToRunLoop(mode: CFRunLoopMode = .defaultMode) {
        CFRunLoopAddSource(RunLoop.current.getCFRunLoop(), AXObserverGetRunLoopSource(self), mode)
        // NSLog("Added observer \(self) to run loop")
    }

    func removeFromRunLoop(mode: CFRunLoopMode = .defaultMode) {
        CFRunLoopRemoveSource(RunLoop.current.getCFRunLoop(), AXObserverGetRunLoopSource(self), mode)
        // NSLog("Removed observer \(self) from run loop")
    }
}

private enum AXObserverError: Error {
    case createFailed(AXError)
    case addNotificationFailed(AXError)
    case removeNotificationFailed(AXError)
}

extension AXUIElement {
    var selectedText: String? {
        rawValue(for: kAXSelectedTextAttribute) as? String
    }

    func rawValue(for attribute: String) -> AnyObject? {
        var rawValue: AnyObject?
        let error = AXUIElementCopyAttributeValue(self, attribute as CFString, &rawValue)
        return error == .success ? rawValue : nil
    }

    func getValue(for attribute: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, attribute as CFString, &result) == .success else { return nil }
        return result
    }

    var children: [AXUIElement]? {
        guard let rawChildren = rawValue(for: kAXChildrenAttribute) else { return nil }
        return rawChildren as? [AXUIElement]
    }

    // Traverses the element's subtree (breadth-first) until visitor() returns false or traversal is completed
    func traverse(visitor: (AXUIElement) -> Bool, element: AXUIElement? = nil) {
        let element = element ?? self
        if let children = element.children {
            for child in children {
                if !visitor(child) { return }
                traverse(visitor: visitor, element: child)
            }
        }
    }
}

class FileMonitor {
    private let fileURL: URL
    private var dispatchObject: DispatchSourceFileSystemObject?

    public var fileChangedEventHandler: (() -> Void)?

    init?(filePath: URL, queue: DispatchQueue) {
        self.fileURL = filePath
        let folderURL = fileURL.deletingLastPathComponent() // monitor enclosing folder to track changes by Xcode
        let descriptor = open(folderURL.path, O_EVTONLY)
        guard descriptor >= -1 else { NSLog("open failed: \(descriptor)"); return nil }
        dispatchObject = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: .write, queue: queue)
        dispatchObject?.setEventHandler { [weak self] in
            self?.fileChangedEventHandler?()
        }
        dispatchObject?.setCancelHandler {
            close(descriptor)
        }
        dispatchObject?.activate()
    }

    deinit {
        dispatchObject?.cancel()
    }
}

enum AXUIElementNotification {
    case selectedTextChanged
    case focusedUIElementChanged
    case focusedWindowChanged
    case valueChanged
    case uknown

    static func notificationFrom(string notification: String) -> AXUIElementNotification {
        switch notification {
            case "AXSelectedTextChanged":
                return .selectedTextChanged
            case "AXFocusedUIElementChanged":
                return .focusedUIElementChanged
            case "AXFocusedWindowChanged":
                return .focusedWindowChanged
            case "AXValueChanged":
                return .valueChanged
            default:
                return .uknown
        }
    }
}
// swiftlint:enable force_cast
