import Foundation

class MonitoringManager {
    enum MonitoringState {
        case on
        case off
    }

    public static let appIDsToWatch = ["com.apple.dt.Xcode", "com.postmanlabs.mac", "com.figma.Desktop"]

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

    static func set(monitoringState: MonitoringState, for bundleId: String) {
        UserDefaults.standard.set(monitoringState == .on, forKey: monitoredKey(bundleId: bundleId))
        UserDefaults.standard.synchronize()

        print("Monitoring \(monitoringState == .on ? "enabled" : "disabled") for \(AppInfo.getAppName(bundleId: bundleId) ?? "")")
    }

    static func monitoredKey(bundleId: String) -> String {
        "is_\(bundleId)_monitored"
    }
}
