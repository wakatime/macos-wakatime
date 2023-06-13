import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    struct Constants {
        static let mainAppBundleID = "macos-wakatime.WakaTime"
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = runningApps.contains {
            $0.bundleIdentifier == Constants.mainAppBundleID
        }

        if !isRunning {
            var path = Bundle.main.bundlePath as NSString
            for _ in 1...4 {
                path = path.deletingLastPathComponent as NSString
            }
            let fileURL = URL(fileURLWithPath: path as String)
            print("Opening", fileURL.absoluteString)
            NSWorkspace.shared.openApplication(
                at: fileURL,
                configuration: NSWorkspace.OpenConfiguration()
            ) { _, error in
                if let error {
                    print(error.localizedDescription)
                }
            }
        }
    }
}
