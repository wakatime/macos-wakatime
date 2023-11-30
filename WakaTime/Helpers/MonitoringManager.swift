import Cocoa
import Foundation

class MonitoringManager {
    enum MonitoringState {
        case on
        case off
    }

    static func isAppMonitored(for bundleId: String) -> Bool {
        guard MonitoredApp.allBundleIds.contains(bundleId) else { return false }

        let isMonitoredKey = monitoredKey(bundleId: bundleId)

        if UserDefaults.standard.string(forKey: isMonitoredKey) != nil {
            let isMonitored = UserDefaults.standard.bool(forKey: isMonitoredKey)
            return isMonitored
        } else {
            UserDefaults.standard.set(false, forKey: isMonitoredKey)
            UserDefaults.standard.synchronize()
        }
        return true
    }

    static func isAppMonitored(_ app: NSRunningApplication) -> Bool {
        guard let bundleId = app.bundleIdentifier else { return false }

        return isAppMonitored(for: bundleId)
    }

    static func isAppElectron(for bundleId: String) -> Bool {
        MonitoredApp.electronAppIds.contains(bundleId)
    }

    static func isAppElectron(_ app: NSRunningApplication) -> Bool {
        guard let bundleId = app.bundleIdentifier else { return false }

        return isAppElectron(for: bundleId)
    }

    static func isAppXcode(_ app: NSRunningApplication) -> Bool {
        guard let bundleId = app.bundleIdentifier else { return false }

        return bundleId == MonitoredApp.xcode.rawValue
    }

    static func heartbeatData(_ app: NSRunningApplication, element: AXUIElement) -> HeartbeatData? {
        guard
            let monitoredApp = app.monitoredApp,
            let title = element.title(for: monitoredApp)
        else { return nil }

        switch monitoredApp {
            case .figma:
                return HeartbeatData(
                    entity: title,
                    language: "Figma Design",
                    category: .designing)
            case .postman:
                return HeartbeatData(
                    entity: title,
                    language: "HTTP Request",
                    category: .debugging)
            case .warp:
                return HeartbeatData(
                    entity: title,
                    category: .coding)
            case .slack:
                return HeartbeatData(
                    entity: title,
                    category: .communicating)
            case .safari:
                return HeartbeatData(
                    entity: title,
                    category: .browsing)
            case .chrome:
                return HeartbeatData(
                    entity: title,
                    category: .browsing)
            case .arcbrowser:
                return HeartbeatData(
                    entity: title,
                    category: .browsing)
            case .imessage:
                return HeartbeatData(
                    entity: title,
                    category: .communicating)
            case .canva:
                return HeartbeatData(
                    entity: title,
                    language: "Canva Design",
                    category: .designing)
            case .whatsapp:
                return HeartbeatData(
                    entity: title,
                    category: .meeting)
            case .zoom:
                return HeartbeatData(
                    entity: title,
                    category: .meeting)
            case .xcode:
                fatalError("Xcode should never use window title")
        }
    }

    static func set(monitoringState: MonitoringState, for bundleId: String) {
        UserDefaults.standard.set(monitoringState == .on, forKey: monitoredKey(bundleId: bundleId))
        UserDefaults.standard.synchronize()
        // NSLog("Monitoring \(monitoringState == .on ? "enabled" : "disabled") for \(AppInfo.getAppName(bundleId: bundleId) ?? "")")
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
