import AppKit

enum MonitoredApp: String, CaseIterable {
    case adobeaftereffect = "com.adobe.AfterEffects"
    case adobebridge = "com.adobe.bridge14"
    case adobeillustrator = "com.adobe.illustrator"
    case adobemediaencoder = "com.adobe.ame.application.24"
    case adobephotoshop = "com.adobe.Photoshop"
    case adobepremierepro = "com.adobe.PremierePro.24"
    case arcbrowser = "company.thebrowser.Browser"
    case beeper = "im.beeper"
    case brave = "com.brave.Browser"
    case canva = "com.canva.CanvaDesktop"
    case chrome = "com.google.Chrome"
    case figma = "com.figma.Desktop"
    case firefox = "org.mozilla.firefox"
    case github = "com.github.GitHubClient"
    case imessage = "com.apple.MobileSMS"
    case iterm2 = "com.googlecode.iterm2"
    case linear = "com.linear"
    case miro = "com.electron.realtimeboard"
    case notes = "com.apple.Notes"
    case notion = "notion.id"
    case postman = "com.postmanlabs.mac"
    case rocketchat = "chat.rocket"
    case safari = "com.apple.Safari"
    case safaripreview = "com.apple.SafariTechnologyPreview"
    case slack = "com.tinyspeck.slackmacgap"
    case tableplus = "com.tinyapp.TablePlus"
    case terminal = "com.apple.Terminal"
    case warp = "dev.warp.Warp-Stable"
    case wecom = "com.tencent.WeWorkMac"
    case whatsapp = "net.whatsapp.WhatsApp"
    case xcode = "com.apple.dt.Xcode"
    case zed = "dev.zed.Zed"
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

    // Hide these from the Monitored Apps menu
    static let unsupportedAppIds = [
        "macos-wakatime.WakaTime",
        "com.apple.finder",
    ]

    static var allBundleIds: [String] {
        MonitoredApp.allCases.map { $0.rawValue }
    }

    static let electronAppIds = [
        MonitoredApp.figma.rawValue,
        MonitoredApp.slack.rawValue,
    ]

    static let browserAppIds = [
        MonitoredApp.arcbrowser.rawValue,
        MonitoredApp.brave.rawValue,
        MonitoredApp.chrome.rawValue,
        MonitoredApp.firefox.rawValue,
        MonitoredApp.safari.rawValue,
        MonitoredApp.safaripreview.rawValue,
    ]

    // list apps which are enabled by default on first run
    static let defaultEnabledApps = [
        MonitoredApp.canva.rawValue,
        MonitoredApp.figma.rawValue,
        MonitoredApp.github.rawValue,
        MonitoredApp.linear.rawValue,
        MonitoredApp.notes.rawValue,
        MonitoredApp.notion.rawValue,
        MonitoredApp.postman.rawValue,
        MonitoredApp.tableplus.rawValue,
        MonitoredApp.xcode.rawValue,
        MonitoredApp.zoom.rawValue,
        MonitoredApp.zed.rawValue,
    ]
}
