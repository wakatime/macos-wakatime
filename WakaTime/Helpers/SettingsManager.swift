import Foundation
import ServiceManagement

class SettingsManager {
#if !SIMULATE_OLD_MACOS
    static let simulateOldMacOS = false
#else
    static let simulateOldMacOS = true
#endif

    static func loginItemRegistered() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status != .notFound
        } else {
            return false
        }
    }

    static func shouldRegisterAsLoginItem() -> Bool {
        guard
            !loginItemRegistered(),
            PropertiesManager.shouldLaunchOnLogin
        else { return false }

        return Bundle.main.version != "local-build"
    }

    static func registerAsLoginItem() {
        PropertiesManager.shouldLaunchOnLogin = true

        // Use SMAppService on macOS 13 or newer to add WakaTime to the "Open at Login" list and SMLoginItemSetEnabled
        // for older versions of macOS to add WakaTime to the "Allow in Background" list
        if #available(macOS 13.0, *), !simulateOldMacOS {
            do {
                try SMAppService.mainApp.register()
                NSLog("Registered for login")
            } catch let error {
                NSLog(error.localizedDescription)
            }
        } else {
            if SMLoginItemSetEnabled("macos-wakatime.WakaTimeHelper" as CFString, true) {
                NSLog("Login item enabled successfully.")
            } else {
                NSLog("Failed to enable login item.")
            }
        }
    }

    static func unregisterAsLoginItem() {
        PropertiesManager.shouldLaunchOnLogin = false

        if #available(macOS 13.0, *), !simulateOldMacOS {
            do {
                try SMAppService.mainApp.unregister()
                NSLog("Unregistered for login")
            } catch let error {
                NSLog(error.localizedDescription)
            }
        } else {
            if SMLoginItemSetEnabled("macos-wakatime.WakaTimeHelper" as CFString, false) {
                NSLog("Login item disabled successfully.")
            } else {
                NSLog("Failed to disable login item.")
            }
        }
    }
}
