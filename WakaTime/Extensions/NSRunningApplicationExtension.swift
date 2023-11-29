import Cocoa

enum MonitoredApp: String, CaseIterable {
    case arcbrowser = "company.thebrowser.Browser"
    case canva = "com.canva.CanvaDesktop"
    case chrome = "com.google.Chrome"
    case figma = "com.figma.Desktop"
    case imessage = "com.apple.MobileSMS"
    case postman = "com.postmanlabs.mac"
    case safari = "com.apple.Safari"
    case slack = "com.tinyspeck.slackmacgap"
    case warp = "dev.warp.Warp-Stable"
    case whatsapp = "net.whatsapp.WhatsApp"
    case xcode = "com.apple.dt.Xcode"
    case zoom = "us.zoom.xos"

    init?(from bundleId: String) {
        if let app = MonitoredApp(rawValue: bundleId) {
            self = app
        } else {
            return nil
        }
    }

    static var allBundleIds: [String] {
        MonitoredApp.allCases.map { $0.rawValue }
    }

    static let electronAppIds = [MonitoredApp.postman.rawValue, MonitoredApp.figma.rawValue,
                                 MonitoredApp.canva.rawValue, MonitoredApp.warp.rawValue,
                                 MonitoredApp.slack.rawValue, MonitoredApp.safari.rawValue,
                                 MonitoredApp.imessage.rawValue, MonitoredApp.chrome.rawValue,
                                 MonitoredApp.arcbrowser.rawValue]
}

extension NSRunningApplication {
    var monitoredApp: MonitoredApp? {
        guard let bundleId = bundleIdentifier else { return nil }

        return .init(from: bundleId)
    }
}
