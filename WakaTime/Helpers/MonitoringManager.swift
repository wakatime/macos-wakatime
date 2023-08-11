import Cocoa
import Foundation

enum App: String {
    case xcode = "com.apple.dt.Xcode"
    case figma = "com.figma.Desktop"
    case postman = "com.postmanlabs.mac"
    case uknown
}

class MonitoringManager {
    enum MonitoringState {
        case on
        case off
    }

    public static let appIDsToWatch = [App.xcode.rawValue, App.postman.rawValue, App.figma.rawValue]
    static let electronAppIds = [App.postman.rawValue, App.figma.rawValue]

    static func isAppMonitored(for bundleId: String) -> Bool {
        guard appIDsToWatch.contains(bundleId) else { return false }

        let isMonitoredKey = monitoredKey(bundleId: bundleId)

        if UserDefaults.standard.string(forKey: isMonitoredKey) != nil {
            let isMonitored = UserDefaults.standard.bool(forKey: isMonitoredKey)
            return isMonitored
        } else {
            UserDefaults.standard.set(true, forKey: isMonitoredKey)
            UserDefaults.standard.synchronize()
        }
        return true
    }

    static func isAppMonitored(_ app: NSRunningApplication) -> Bool {
        guard let bundleId = app.bundleIdentifier else { return false }

        return isAppMonitored(for: bundleId)
    }

    static func isAppElectron(for bundleId: String) -> Bool {
        electronAppIds.contains(bundleId)
    }

    static func isAppElectron(_ app: NSRunningApplication) -> Bool {
        guard let bundleId = app.bundleIdentifier else { return false }

        return isAppElectron(for: bundleId)
    }

    static func entityFromWindowTitle(_ app: NSRunningApplication, element: AXUIElement) -> String? {
        guard let bundleId = app.bundleIdentifier else { return nil }

        var windowTitle: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &windowTitle)
        guard
            let title = windowTitle as? String,
            title != ""
        else { return nil }

        switch bundleId {
            case App.figma.rawValue:
                guard title.trimmingCharacters(in: .whitespacesAndNewlines) != "Figma" else { return nil }
                let parts = title.components(separatedBy: " – ")
                if parts.count > 1 && parts[0].trimmingCharacters(in: .whitespacesAndNewlines) != "" {
                    return parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                }
            case App.postman.rawValue:
                guard title.trimmingCharacters(in: .whitespacesAndNewlines) != "Postman" else { return nil }
                let parts = title.components(separatedBy: " | ")
                if parts.count > 1 && parts[0].trimmingCharacters(in: .whitespacesAndNewlines) != "" {
                    return parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                }
            default:
                break
        }

        return title
    }

    static func set(monitoringState: MonitoringState, for bundleId: String) {
        UserDefaults.standard.set(monitoringState == .on, forKey: monitoredKey(bundleId: bundleId))
        UserDefaults.standard.synchronize()

        print("Monitoring \(monitoringState == .on ? "enabled" : "disabled") for \(AppInfo.getAppName(bundleId: bundleId) ?? "")")
    }

    static func monitoredKey(bundleId: String) -> String {
        "is_\(bundleId)_monitored"
    }
}
