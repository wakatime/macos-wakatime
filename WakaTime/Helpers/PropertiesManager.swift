import Foundation

class PropertiesManager {
    enum Keys: String {
        case shouldLaunchOnLogin = "launch_on_login"
        case shouldAutomaticallyDownloadUpdates = "should_automatically_download_updates"
    }
    static var shouldLaunchOnLogin: Bool {
        get {
            guard UserDefaults.standard.string(forKey: Keys.shouldLaunchOnLogin.rawValue) != nil else {
                UserDefaults.standard.set(true, forKey: Keys.shouldLaunchOnLogin.rawValue)
                return true
            }

            return UserDefaults.standard.bool(forKey: Keys.shouldLaunchOnLogin.rawValue)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.shouldLaunchOnLogin.rawValue)
            UserDefaults.standard.synchronize()
        }
    }

    static var shouldAutomaticallyDownloadUpdates: Bool {
        get {
            guard UserDefaults.standard.string(forKey: Keys.shouldAutomaticallyDownloadUpdates.rawValue) != nil else {
                UserDefaults.standard.set(true, forKey: Keys.shouldAutomaticallyDownloadUpdates.rawValue)
                return true
            }

            return UserDefaults.standard.bool(forKey: Keys.shouldAutomaticallyDownloadUpdates.rawValue)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.shouldAutomaticallyDownloadUpdates.rawValue)
            UserDefaults.standard.synchronize()
        }
    }
}
