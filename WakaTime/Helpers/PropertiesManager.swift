import Foundation

class PropertiesManager {
    enum DomainPreferenceType: String {
        case domain
        case url
    }

    enum FilterType: String {
        case denylist
        case allowlist
    }

    enum Keys: String {
        case shouldLaunchOnLogin = "launch_on_login"
        case shouldLogToFile = "log_to_file"
        case shouldAutomaticallyDownloadUpdates = "should_automatically_download_updates"
        case hasLaunchedBefore = "has_launched_before"
        case domainPreference = "domain_preference"
        case filterType = "filter_type"
        case denylist = "denylist"
        case allowlist = "allowlist"
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

    static var domainPreference: DomainPreferenceType {
        get {
            guard let domainPreferenceString = UserDefaults.standard.string(forKey: Keys.domainPreference.rawValue) else {
                return .domain
            }

            return DomainPreferenceType(rawValue: domainPreferenceString) ?? .domain
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Keys.domainPreference.rawValue)
            UserDefaults.standard.synchronize()
        }
    }

    static var filterType: FilterType {
        get {
            guard let filterTypeString = UserDefaults.standard.string(forKey: Keys.filterType.rawValue) else {
                return .allowlist
            }

            return FilterType(rawValue: filterTypeString) ?? .denylist
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Keys.filterType.rawValue)
            UserDefaults.standard.synchronize()
        }
    }

    static var denylist: String {
        get {
            guard let denylist = UserDefaults.standard.string(forKey: Keys.denylist.rawValue) else {
                return ""
            }

            return denylist
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.denylist.rawValue)
            UserDefaults.standard.synchronize()
        }
    }

    static var allowlist: String {
        get {
            guard let allowlist = UserDefaults.standard.string(forKey: Keys.allowlist.rawValue) else {
                return
                    "https?://(\\w\\.)*github\\.com/\n" +
                    "https?://(\\w\\.)*gitlab\\.com/\n" +
                    "^stackoverflow\\.com/\n" +
                    "^docs\\.python\\.org/\n" +
                    "https?://(\\w\\.)*golang\\.org/\n" +
                    "https?://(\\w\\.)*go\\.dev/\n" +
                    "https?://(\\w\\.)*npmjs\\.com/\n" +
                    "https?//localhost[:\\d+]?/"
            }

            return allowlist
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.allowlist.rawValue)
            UserDefaults.standard.synchronize()
        }
    }

    static var currentFilterList: String {
        switch Self.filterType {
            case .denylist: return Self.denylist
            case .allowlist: return Self.allowlist
        }
    }
}
