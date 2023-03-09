import Foundation
import AppKit

class Watcher: NSObject {
    
    private static let appIDsToWatch = ["com.apple.dt.Xcode"]
    private static let axNotificationName = kAXFocusedUIElementChangedNotification as CFString
    
    public var xcodeVersion: String? = nil
    public var changeHandler: ((_ path: String, _ isWrite: Bool) -> Void)?
    public private(set) var activeApp: NSRunningApplication? = nil
    private var observer: AXObserver?
    private var observingElement: AXUIElement?
    private var fileMonitor: FileMonitor?
    
    
    override init() {
        super.init()
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(appChanged), name: NSWorkspace.didActivateApplicationNotification, object: nil)
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
        var error = AXObserverCreate(app.processIdentifier, observerCallback, &observer)
        guard error == .success else { NSLog("AXObserverCreateWithInfoCallback failed: \(error.rawValue)"); return }
        guard let observer else { return }
        
        let this = Unmanaged.passUnretained(self).toOpaque()
        observingElement = AXUIElementCreateApplication(app.processIdentifier)
        error = AXObserverAddNotification(observer, observingElement!, Watcher.axNotificationName, this)
        guard error == .success else { NSLog("AXObserverAddNotification failed: \(error.rawValue)"); return }
        
        observer.addToRunLoop()
        
        NSLog("Watching for file changes on \(app.localizedName!)")
    }
    
    private func unwatch(app: NSRunningApplication) {
        if let observer {
            observer.removeFromRunLoop()
            guard let observingElement else { NSLog("observingElement should not be nil here"); return }
            AXObserverRemoveNotification(observer, observingElement, Watcher.axNotificationName)
            self.observingElement = nil
            self.observer = nil
            NSLog("Stopped watching \(app.localizedName!)")
        }
    }
    
    fileprivate func documentChanged(_ path: String) {
        NSLog("Document changed to \(path)")
        changeHandler?(path, false)
        fileMonitor = nil
        do {
            try fileMonitor = FileMonitor(filePath: path)
        }
        catch {
            NSLog("Failed to create FileMonitor: \(error.localizedDescription)")
        }
    }
}


fileprivate func observerCallback(_ observer: AXObserver, _ element: AXUIElement, _ notification: CFString, _ refcon: UnsafeMutableRawPointer?) {
    if let window = element.getValue(for: kAXWindowAttribute) {
        guard CFGetTypeID(element) == AXUIElementGetTypeID() else { return }
        if var path = (window as! AXUIElement).getValue(for: kAXDocumentAttribute) as? String {
            guard let refcon else { return }
            let this = Unmanaged<Watcher>.fromOpaque(refcon).takeUnretainedValue()
            if path.hasPrefix("file://") {
                path = path.dropFirst(7).description
            }
            this.documentChanged(path)
        }
    }
}


fileprivate extension AXObserver {
    func addToRunLoop() {
        CFRunLoopAddSource(RunLoop.current.getCFRunLoop(), AXObserverGetRunLoopSource(self), .defaultMode)
        NSLog("Added AXObserver \(self) to run loop")
    }
    
    func removeFromRunLoop() {
        CFRunLoopRemoveSource(RunLoop.current.getCFRunLoop(), AXObserverGetRunLoopSource(self), .defaultMode)
        NSLog("Removed AXObserver \(self) from run loop")
    }
}


fileprivate extension AXUIElement {
    func getValue(for attribute: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, attribute as CFString, &result) == .success else { return nil }
        return result
    }
}



fileprivate class FileMonitor {
    private let fileURL: URL
    private let fileHandle: FileHandle
    private let fileObject: DispatchSourceFileSystemObject
    
    public var changeHandler: ((_ path: String) -> Void)?
    
    init(filePath: String) throws {
        fileURL = URL(string: filePath)!
        fileHandle = try FileHandle(forReadingFrom: fileURL)
        fileObject = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileHandle.fileDescriptor, eventMask: .extend, queue: .main)
        fileObject.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.changeHandler?(self.fileURL.path())
        }
        fileObject.setCancelHandler { [weak self] in
            self?.fileHandle.closeFile()
        }
        fileHandle.seekToEndOfFile()
        fileObject.resume()
        NSLog("Created FileMonitor for \(fileURL.path())")
    }
    
    deinit {
        fileObject.cancel()
        NSLog("Deleted FileMonitor for \(fileURL.path())")
    }
}
