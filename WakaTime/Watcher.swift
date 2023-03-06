import Foundation
import AppKit

class Watcher: NSObject {

    public private(set) var activeApp : NSRunningApplication? = nil
    
    override init (){
        super.init()
        
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(self.appChangeHandler),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil)
    }

    @objc private func appChangeHandler(notification : NSNotification) -> Void {
        let app = notification.userInfo!["NSWorkspaceApplicationKey"] as! NSRunningApplication
        self.activeApp = app
        print(app.localizedName!)
        print(app.bundleIdentifier!)
        print(app.bundleURL!)
    }
}
