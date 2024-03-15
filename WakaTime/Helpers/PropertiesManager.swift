import Foundation

class PropertiesManager {
    enum Keys: String {
        case shouldLaunchOnLogin = "launch_on_login"
        case shouldLogToFile = "log_to_file"
        case shouldAutomaticallyDownloadUpdates = "should_automatically_download_updates"
        case hasLaunchedBefore = "has_launched_before"
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

    static var shouldLogToFile: Bool {
        get {
            guard UserDefaults.standard.string(forKey: Keys.shouldLogToFile.rawValue) != nil else {
                UserDefaults.standard.set(false, forKey: Keys.shouldLogToFile.rawValue)
                return false
            }

            return UserDefaults.standard.bool(forKey: Keys.shouldLogToFile.rawValue)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.shouldLogToFile.rawValue)
            UserDefaults.standard.synchronize()
            if newValue {
                Logging.default.activateLoggingToFile()
            } else {
                Logging.default.deactivateLoggingToFile()
            }
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

    static var hasLaunchedBefore: Bool {
        get {
            guard UserDefaults.standard.string(forKey: Keys.hasLaunchedBefore.rawValue) != nil else {
                return false
            }

            return UserDefaults.standard.bool(forKey: Keys.hasLaunchedBefore.rawValue)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.hasLaunchedBefore.rawValue)
            UserDefaults.standard.synchronize()
        }
    }
}
