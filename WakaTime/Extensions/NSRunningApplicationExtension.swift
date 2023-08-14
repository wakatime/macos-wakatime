import Cocoa

enum MonitoredApp: String, CaseIterable {
    case xcode = "com.apple.dt.Xcode"
    case figma = "com.figma.Desktop"
    case canva = "com.canva.CanvaDesktop"
    case postman = "com.postmanlabs.mac"

    init?(from bundleId: String) {
        if let app = MonitoredApp(rawValue: bundleId) {
            self = app
        }
        return nil
    }

    static var allBundleIds: [String] {
        MonitoredApp.allCases.map { $0.rawValue }
    }

    static let electronAppIds = [MonitoredApp.postman.rawValue, MonitoredApp.figma.rawValue, MonitoredApp.canva.rawValue]
}

extension NSRunningApplication {
    var monitoredApp: MonitoredApp? {
        guard let bundleId = bundleIdentifier else { return nil }

        return .init(from: bundleId)
    }
}
