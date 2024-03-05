import Cocoa
import Foundation

class MonitoringManager {
    enum MonitoringState {
        case on
        case off
    }

    static func isAppMonitored(for bundleId: String) -> Bool {
        guard
            MonitoredApp.allBundleIds.contains(bundleId) ||
            MonitoredApp.allBundleIds.contains(bundleId.replacingOccurrences(of: "-setapp$", with: "", options: .regularExpression))
        else { return false }

        guard
            !MonitoredApp.unsuportedAppIds.contains(bundleId),
            !MonitoredApp.unsuportedAppIds.contains(bundleId.replacingOccurrences(of: "-setapp$", with: "", options: .regularExpression))
        else { return false }

        let isMonitoredKey = monitoredKey(bundleId: bundleId)

        if UserDefaults.standard.string(forKey: isMonitoredKey) != nil {
            return UserDefaults.standard.bool(forKey: isMonitoredKey)
        } else {
            UserDefaults.standard.set(false, forKey: isMonitoredKey)
            UserDefaults.standard.synchronize()
            return false
        }
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

    static func heartbeatData(_ app: NSRunningApplication) -> HeartbeatData? {
        let pid = app.processIdentifier
        var element = AXUIElementCreateApplication(pid)
        element = element.activeWindow ?? element

        guard
            let monitoredApp = app.monitoredApp,
            let title = element.title(for: monitoredApp)
        else { return nil }

        switch monitoredApp {
            case .arcbrowser:
                return HeartbeatData(
                    entity: title,
                    category: .browsing)
            case .canva:
                return HeartbeatData(
                    entity: title,
                    language: "Canva Design",
                    category: .designing)
            case .chrome:
                return HeartbeatData(
                    entity: title,
                    category: .browsing)
            case .figma:
                return HeartbeatData(
                    entity: title,
                    language: "Figma Design",
                    category: .designing)
            case .imessage:
                return HeartbeatData(
                    entity: title,
                    category: .communicating)
            case .iterm2:
                return HeartbeatData(
                    entity: title,
                    category: .coding)
            case .linear:
                return HeartbeatData(
                    entity: title,
                    category: .planning)
            case .notes:
                if element.rawTitle == "Notes" {
                    return HeartbeatData(
                        entity: title,
                        category: .learning
                    )
                } else {
                    return nil
                }
            case .notion:
                return HeartbeatData(
                    entity: title,
                    category: .learning)
            case .postman:
                return HeartbeatData(
                    entity: title,
                    language: "HTTP Request",
                    category: .debugging)
            case .slack:
                return HeartbeatData(
                    entity: title,
                    category: .communicating)
            case .safari:
                return HeartbeatData(
                    entity: title,
                    category: .browsing)
            case .safaripreview:
                return HeartbeatData(
                    entity: title,
                    category: .browsing)
            case .tableplus:
                return HeartbeatData(
                    entity: title,
                    category: .debugging)
            case .terminal:
                return HeartbeatData(
                    entity: title,
                    category: .coding)
            case .warp:
                return HeartbeatData(
                    entity: title,
                    category: .coding)
            case .wecom:
                return HeartbeatData(
                    entity: title,
                    category: .communicating)
            case .whatsapp:
                return HeartbeatData(
                    entity: title,
                    category: .meeting)
            case .xcode:
                fatalError("\(monitoredApp.rawValue) should never use window title")
            case .zoom:
                return HeartbeatData(
                    entity: title,
                    category: .meeting)
        }
    }

    static func set(monitoringState: MonitoringState, for bundleId: String) {
        UserDefaults.standard.set(monitoringState == .on, forKey: monitoredKey(bundleId: bundleId))
        UserDefaults.standard.synchronize()
        // NSLog("Monitoring \(monitoringState == .on ? "enabled" : "disabled") for \(AppInfo.getAppName(bundleId: bundleId) ?? "")")
    }

    static func enableByDefault(_ bundleId: String) {
        if AppInfo.getIcon(bundleId: bundleId) != nil && AppInfo.getAppName(bundleId: bundleId) != nil {
            MonitoringManager.set(monitoringState: .on, for: bundleId)
        }
        let setAppId = bundleId.appending("-setapp")
        if AppInfo.getIcon(bundleId: setAppId) != nil && AppInfo.getAppName(bundleId: setAppId) != nil {
            MonitoringManager.set(monitoringState: .on, for: setAppId)
        }
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
