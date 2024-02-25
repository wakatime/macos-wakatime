import Cocoa

enum MonitoredApp: String, CaseIterable {
    case arcbrowser = "company.thebrowser.Browser"
    case canva = "com.canva.CanvaDesktop"
    case chrome = "com.google.Chrome"
    case figma = "com.figma.Desktop"
    case imessage = "com.apple.MobileSMS"
    case iterm2 = "com.googlecode.iterm2"
    case linear = "com.linear"
    case notes = "com.apple.Notes"
    case notion = "notion.id"
    case postman = "com.postmanlabs.mac"
    case safari = "com.apple.Safari"
    case safaripreview = "com.apple.SafariTechnologyPreview"
    case slack = "com.tinyspeck.slackmacgap"
    case tableplus = "com.tinyapp.TablePlus"
    case terminal = "com.apple.Terminal"
    case warp = "dev.warp.Warp-Stable"
    case wecom = "com.tencent.WeWorkMac"
    case whatsapp = "net.whatsapp.WhatsApp"
    case xcode = "com.apple.dt.Xcode"
    case zoom = "us.zoom.xos"

    init?(from bundleId: String) {
        if let app = MonitoredApp(rawValue: bundleId) {
            self = app
        } else if let app = MonitoredApp(rawValue: bundleId.replacingOccurrences(of: "-setapp$", with: "", options: .regularExpression)) {
            self = app
        } else {
            return nil
        }
    }

    static var allBundleIds: [String] {
        MonitoredApp.allCases.map { $0.rawValue }
    }

    static let electronAppIds = [
        MonitoredApp.arcbrowser.rawValue,
        MonitoredApp.canva.rawValue,
        MonitoredApp.chrome.rawValue,
        MonitoredApp.figma.rawValue,
        MonitoredApp.imessage.rawValue,
        MonitoredApp.iterm2.rawValue,
        MonitoredApp.linear.rawValue,
        MonitoredApp.notes.rawValue,
        MonitoredApp.notion.rawValue,
        MonitoredApp.postman.rawValue,
        MonitoredApp.slack.rawValue,
        MonitoredApp.safari.rawValue,
        MonitoredApp.safaripreview.rawValue,
        MonitoredApp.tableplus.rawValue,
        MonitoredApp.terminal.rawValue,
        MonitoredApp.warp.rawValue,
    ]
}

extension NSRunningApplication {
    var monitoredApp: MonitoredApp? {
        guard let bundleId = bundleIdentifier else { return nil }

        return .init(from: bundleId)
    }
}
