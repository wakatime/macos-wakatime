import Foundation
import ServiceManagement

class SettingsManager {
    static func registerAsLoginItem() {
        PropertiesManager.shouldLaunchOnLogin = true

        if SMLoginItemSetEnabled("macos-wakatime.WakaTimeHelper" as CFString, true) {
            print("Login item enabled successfully.")
        } else {
            print("Failed to enable login item.")
        }
    }

    static func unregisterAsLoginItem() {
        PropertiesManager.shouldLaunchOnLogin = false

        if SMLoginItemSetEnabled("macos-wakatime.WakaTimeHelper" as CFString, false) {
            print("Login item disabled successfully.")
        } else {
            print("Failed to disable login item.")
        }
    }
}
