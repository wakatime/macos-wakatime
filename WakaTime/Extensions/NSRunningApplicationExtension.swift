import Cocoa

enum MonitoredApp: String, CaseIterable {
    case xcode = "com.apple.dt.Xcode"
    case figma = "com.figma.Desktop"
    case postman = "com.postmanlabs.mac"
    case canva = "com.canva.CanvaDesktop"

    init?(from bundleId: String) {
        switch bundleId {
            case MonitoredApp.xcode.rawValue:
                self = .xcode
            case MonitoredApp.figma.rawValue:
                self = .figma
            case MonitoredApp.canva.rawValue:
                self = .canva
            case MonitoredApp.postman.rawValue:
                self = .postman
            default:
                return nil
        }
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
