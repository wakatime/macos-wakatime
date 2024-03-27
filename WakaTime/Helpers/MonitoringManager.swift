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
            !MonitoredApp.unsupportedAppIds.contains(bundleId),
            !MonitoredApp.unsupportedAppIds.contains(bundleId.replacingOccurrences(of: "-setapp$", with: "", options: .regularExpression))
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

    static func isAppBrowser(for bundleId: String) -> Bool {
        MonitoredApp.browserAppIds.contains(bundleId)
    }

    static func isAppBrowser(_ app: NSRunningApplication) -> Bool {
        guard let bundleId = app.bundleIdentifier else { return false }

        return isAppBrowser(for: bundleId)
    }

    static func heartbeatData(_ app: NSRunningApplication) -> HeartbeatData? {
        let pid = app.processIdentifier

        guard
            let monitoredApp = app.monitoredApp,
            let activeWindow = AXUIElementCreateApplication(pid).activeWindow,
            let entity = monitoredApp.entity(for: activeWindow, app)
        else { return nil }

        return HeartbeatData(
            entity: entity,
            project: monitoredApp.project(for: activeWindow),
            language: monitoredApp.language,
            category: monitoredApp.category
        )
    }

    static var isMonitoringBrowsing: Bool {
        for bundleId in MonitoredApp.browserAppIds {
            guard
                AppInfo.getAppName(bundleId: bundleId) != nil,
                isAppMonitored(for: bundleId)
            else { continue }

            return true
        }
        return false
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
    var project: String?
    var language: String?
    var category: Category?
}
