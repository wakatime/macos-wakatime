import Foundation

class PropertiesManager {
    enum FilterType: String {
        case blacklist
        case whitelist
    }

    enum Keys: String {
        case shouldLaunchOnLogin = "launch_on_login"
        case shouldLogToFile = "log_to_file"
        case shouldAutomaticallyDownloadUpdates = "should_automatically_download_updates"
        case hasLaunchedBefore = "has_launched_before"
        case filterType = "filter_type"
        case blacklist = "blacklist"
        case whitelist = "whitelist"
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

    static var filterType: FilterType {
        get {
            guard let filterTypeString = UserDefaults.standard.string(forKey: Keys.filterType.rawValue) else {
                return .whitelist
            }

            return FilterType(rawValue: filterTypeString) ?? .blacklist
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Keys.filterType.rawValue)
            UserDefaults.standard.synchronize()
        }
    }

    static var blacklist: String {
        get {
            guard let blacklist = UserDefaults.standard.string(forKey: Keys.blacklist.rawValue) else {
                return ""
            }

            return blacklist
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.blacklist.rawValue)
            UserDefaults.standard.synchronize()
        }
    }

    static var whitelist: String {
        get {
            guard let whitelist = UserDefaults.standard.string(forKey: Keys.whitelist.rawValue) else {
                return
                    "https://github.com/\n" +
                    "https://gitlab.com/\n" +
                    "https://stackoverflow.com/\n" +
                    "https://docs.python.org/\n" +
                    "https://google.com/\n" +
                    "https://npmjs.com"
            }

            return whitelist
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.whitelist.rawValue)
            UserDefaults.standard.synchronize()
        }
    }

    static var currentFilterList: String {
        switch Self.filterType {
            case .blacklist: return Self.blacklist
            case .whitelist: return Self.whitelist
        }
    }
}
