import Foundation
import AppKit

class Watcher: NSObject {

    public private(set) var activeApp : NSRunningApplication? = nil
    private var observer: AXObserver?
    
    override init (){
        super.init()
        
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(self.appChanged),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil)
    }

    @objc private func appChanged(notification : NSNotification) -> Void {
        let app = notification.userInfo!["NSWorkspaceApplicationKey"] as! NSRunningApplication
        self.activeApp = app
        
        guard app.bundleIdentifier == "com.apple.dt.Xcode" else { return }
        watchApp(app)
    }
    
    private func watchApp(_ app: NSRunningApplication) {
        let error = AXObserverCreateWithInfoCallback(
            app.processIdentifier,
            internalInfoCallback,
            &observer
        )
        
        guard error == .success else {
            print(error)
            return
        }
        
        guard let observer else { return }
        
        print("Watching for element changes on \(app.localizedName!)")
        
        let observingElement = AXUIElementCreateApplication(app.processIdentifier)
        AXObserverAddNotification(observer, observingElement, kAXFocusedUIElementChangedNotification as CFString, nil)
    }
    
    private func elementCallback(
        observer: AXObserver,
        element: AXUIElement,
        notificationName: CFString,
        userInfo: CFDictionary,
        pointer: UnsafeMutableRawPointer?
    ) {
        print(notificationName)
    }
}

private func internalInfoCallback(_ axObserver: AXObserver,
                                  axElement: AXUIElement,
                                  notification: CFString,
                                  cfInfo: CFDictionary,
                                  userData: UnsafeMutableRawPointer?) {
    guard let userData = userData else { fatalError("userData should be an AXSwift.Observer") }

    let observer = Unmanaged<Watcher>.fromOpaque(userData).takeUnretainedValue()
    let info = cfInfo as NSDictionary? as! [String: AnyObject]?
    print(notification)
    print(axElement)
}
