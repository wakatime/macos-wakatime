import Foundation
import AppKit

// swiftlint:disable force_cast
class Watcher: NSObject {
    private static let appIDsToWatch = ["com.apple.dt.Xcode"]

    private let callbackQueue = DispatchQueue(label: "com.WakaTime.Watcher.callbackQueue", qos: .utility)
    private let monitorQueue = DispatchQueue(label: "com.WakaTime.Watcher.monitorQueue", qos: .utility)

    public var xcodeVersion: String?
    public var changeHandler: ((_ path: String, _ isWrite: Bool) -> Void)?
    private var activeApp: NSRunningApplication?
    private var observer: AXObserver?
    private var observingElement: AXUIElement?
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
            if let newAppID = app.bundleIdentifier, Watcher.appIDsToWatch.contains(newAppID) {
                watch(app: app)
            } else if let oldApp = activeApp {
                unwatch(app: oldApp)
            }
            activeApp = app
        }
    }

    private func setXcodeVersion(_ app: NSRunningApplication) {
        guard
            let url = app.bundleURL,
            let bundle = Bundle(url: url),
            let info = bundle.infoDictionary
        else { return }

        let build = info["CFBundleVersion"] as! String
        let version = info["CFBundleShortVersionString"] as! String

        xcodeVersion = "\(version)-\(build)"
    }

    private func watch(app: NSRunningApplication) {
        setXcodeVersion(app)
        do {
            let observer = try AXObserver.create(appID: app.processIdentifier, callback: observerCallback)
            let this = Unmanaged.passUnretained(self).toOpaque()
            let element = AXUIElementCreateApplication(app.processIdentifier)
            try observer.add(notification: kAXFocusedUIElementChangedNotification, element: element, refcon: this)
            try observer.add(notification: kAXSelectedTextChangedNotification, element: element, refcon: this)
            try observer.add(notification: kAXValueChangedNotification, element: element, refcon: this)
            observer.addToRunLoop()
            self.observer = observer
            self.observingElement = element
            NSLog("Watching for file changes on \(app.localizedName ?? "nil")")
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
            NSLog("Stopped watching \(app.localizedName ?? "nil")")
        }
    }

    var documentPath: String? {
        didSet {
            if documentPath != oldValue {
                guard let newPath = documentPath else { return }

                documentChanged(path: newPath, isWrite: false)
                fileMonitor = nil
                fileMonitor = FileMonitor(filePath: newPath, queue: monitorQueue)
                fileMonitor?.changeHandler = { [weak self] in
                    self?.documentChanged(path: newPath, isWrite: true)
                }
            }
        }
    }

    private func documentChanged(path: String, isWrite: Bool) {
        callbackQueue.async {
            NSLog("Document changed: \(path) isWrite: \(isWrite)")
            self.changeHandler?(path, isWrite)
        }
    }
}

private func observerCallback(
    _ observer: AXObserver,
    _ element: AXUIElement,
    _ notification: CFString,
    _ refcon: UnsafeMutableRawPointer?
) {
    let notificationString = notification as String
    switch notificationString {
        case "AXValueChanged":
            // TODO: - Find what type of action to monitor
            if let valueDescription = element.valueDescription {
                print("value description: \(valueDescription)")
            }
        case "AXSelectedTextChanged":
            if let selectedText = element.selectedText, !selectedText.isEmpty {
                print("Selected text changed:  \(selectedText)")
            }
        case "AXFocusedUIElementChanged":
            if let window = element.getValue(for: kAXWindowAttribute) {
                guard CFGetTypeID(element) == AXUIElementGetTypeID() else { return }

                if var path = (window as! AXUIElement).getValue(for: kAXDocumentAttribute) as? String {
                    guard let refcon else { return }

                    let this = Unmanaged<Watcher>.fromOpaque(refcon).takeUnretainedValue()
                    if path.hasPrefix("file://") {
                        path = path.dropFirst(7).description
                    }
                    this.documentPath = path
                    print("have new document path: \(path)")
                }
            }
        default:
            break
    }
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

        NSLog("Added notification \(notification) to observer \(self)")
    }

    func remove(notification: String, element: AXUIElement) throws {
        let error = AXObserverRemoveNotification(self, element, notification as CFString)
        guard error == .success else {
            NSLog("Remove notification \(notification) failed: \(error.rawValue)")
            throw AXObserverError.removeNotificationFailed(error)
        }

        NSLog("Removed notification \(notification) from observer \(self)")
    }

    func addToRunLoop(mode: CFRunLoopMode = .defaultMode) {
        CFRunLoopAddSource(RunLoop.current.getCFRunLoop(), AXObserverGetRunLoopSource(self), mode)
        NSLog("Added observer \(self) to run loop")
    }

    func removeFromRunLoop(mode: CFRunLoopMode = .defaultMode) {
        CFRunLoopRemoveSource(RunLoop.current.getCFRunLoop(), AXObserverGetRunLoopSource(self), mode)
        NSLog("Removed observer \(self) from run loop")
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
    var valueDescription: String? {
        rawValue(for: kAXValueAttribute) as? String
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
}

class FileMonitor {
    private let fileURL: URL
    private var dispatchObject: DispatchSourceFileSystemObject?

    public var changeHandler: (() -> Void)?

    init?(filePath: String, queue: DispatchQueue) {
        fileURL = URL(fileURLWithPath: filePath)
        let folderURL = fileURL.deletingLastPathComponent() // monitor enclosing folder to track changes by Xcode
        let descriptor = open(folderURL.path, O_EVTONLY)
        guard descriptor >= -1 else { NSLog("open failed: \(descriptor)"); return nil }
        dispatchObject = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: .write, queue: queue)
        dispatchObject?.setEventHandler { [weak self] in
            self?.changeHandler?()
        }
        dispatchObject?.setCancelHandler {
            close(descriptor)
        }
        dispatchObject?.activate()
        NSLog("Created FileMonitor for \(fileURL.path())")
    }

    deinit {
        dispatchObject?.cancel()
        NSLog("Deleted FileMonitor for \(fileURL.path())")
    }
}
