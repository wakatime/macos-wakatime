import Foundation
import ServiceManagement

class SettingsManager {
    static func registerAsLoginItem() {
        PropertiesManager.shouldLaunchOnLogin = true

        do {
            try SMAppService.mainApp.register()
            print("Registered for login")
        } catch let error {
            print(error)
        }
    }

    static func unregisterAsLoginItem() {
        PropertiesManager.shouldLaunchOnLogin = false

        do {
            try SMAppService.mainApp.unregister()
            print("Unregistered for login")
        } catch let error {
            print(error)
        }
    }

}
