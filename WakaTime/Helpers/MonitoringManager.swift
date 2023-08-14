import Cocoa
import Foundation

enum App: String, CaseIterable {
    case xcode = "com.apple.dt.Xcode"
    case figma = "com.figma.Desktop"
    case postman = "com.postmanlabs.mac"
    case canva = "com.canva.CanvaDesktop"
}

class MonitoringManager {
    enum MonitoringState {
        case on
        case off
    }

    public static let appIDsToWatch = App.allCases.map { $0.rawValue }
    static let electronAppIds = [App.postman.rawValue, App.figma.rawValue, App.canva.rawValue]

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

    static func heartbeatData(_ app: NSRunningApplication, element: AXUIElement) -> HeartbeatData? {
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
                    return HeartbeatData(
                        entity: parts[0].trimmingCharacters(in: .whitespacesAndNewlines),
                        language: "Figma Design",
                        category: .designing)
                }
            case App.postman.rawValue:
                guard title.trimmingCharacters(in: .whitespacesAndNewlines) != "Postman" else { return nil }
                let parts = title.components(separatedBy: " | ")
                if parts.count > 1 && parts[0].trimmingCharacters(in: .whitespacesAndNewlines) != "" {
                    return HeartbeatData(
                        entity: parts[0].trimmingCharacters(in: .whitespacesAndNewlines),
                        language: "HTTP Request",
                        category: .designing)
                }
            case App.canva.rawValue:
                guard
                    title.contains("Canva"),
                    title != "Home - Canva",
                    title.trimmingCharacters(in: .whitespacesAndNewlines) != "Canva"
                else { return nil }
                let parts = title.components(separatedBy: " - ")
                if parts.count > 1 && parts[0].trimmingCharacters(in: .whitespacesAndNewlines) != "" {
                    return HeartbeatData(
                        entity: parts[0].trimmingCharacters(in: .whitespacesAndNewlines),
                        language: "Canva Design",
                        category: .designing)
                }
            default:
                let parts = title.components(separatedBy: " - ")
                if parts.count > 1 && parts[0].trimmingCharacters(in: .whitespacesAndNewlines) != "" {
                    return HeartbeatData(entity: parts[0].trimmingCharacters(in: .whitespacesAndNewlines))
                }
                let partsByPipe = title.components(separatedBy: " | ")
                if partsByPipe.count > 1 && partsByPipe[0].trimmingCharacters(in: .whitespacesAndNewlines) != "" {
                    return HeartbeatData(entity: parts[0].trimmingCharacters(in: .whitespacesAndNewlines))
                }
        }

        return HeartbeatData(entity: title)
    }

    static func set(monitoringState: MonitoringState, for bundleId: String) {
        UserDefaults.standard.set(monitoringState == .on, forKey: monitoredKey(bundleId: bundleId))
        UserDefaults.standard.synchronize()
        // print("Monitoring \(monitoringState == .on ? "enabled" : "disabled") for \(AppInfo.getAppName(bundleId: bundleId) ?? "")")
    }

    static func monitoredKey(bundleId: String) -> String {
        "is_\(bundleId)_monitored"
    }
}

struct HeartbeatData {
  var entity: String
  var language: String?
  var category: Category?
}
