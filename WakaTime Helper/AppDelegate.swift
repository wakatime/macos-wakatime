import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    struct Constants {
        static let mainAppBundleID = "macos-wakatime.WakaTime"
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let userHome = FileManager.default.homeDirectoryForCurrentUser.pathComponents
        let logFilePath = NSString.path(withComponents: userHome + [".wakatime", "macos-wakatime-helper.log"])
        Logging.default.configure(filePath: logFilePath)

        Logging.default.log("Starting WakaTime Helper")

        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = runningApps.contains {
            $0.bundleIdentifier == Constants.mainAppBundleID
        }

        if !isRunning {
            Logging.default.log("WakaTime is not running")
            var path = Bundle.main.bundlePath as NSString
            for _ in 1...4 {
                path = path.deletingLastPathComponent as NSString
            }
            let fileURL = URL(fileURLWithPath: path as String)
            Logging.default.log("Attempting to open WakaTime at \"\(fileURL.absoluteString)\"")
            NSWorkspace.shared.openApplication(
                at: fileURL,
                configuration: NSWorkspace.OpenConfiguration()
            ) { _, error in
                if let error {
                    Logging.default.log(error.localizedDescription)
                }
            }
        } else {
            Logging.default.log("WakaTime is already running")
        }
    }
}
