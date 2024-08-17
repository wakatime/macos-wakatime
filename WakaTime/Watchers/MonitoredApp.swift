import AppKit

enum MonitoredApp: String, CaseIterable {
    case arcbrowser = "company.thebrowser.Browser"
    case brave = "com.brave.Browser"
    case canva = "com.canva.CanvaDesktop"
    case chrome = "com.google.Chrome"
    case figma = "com.figma.Desktop"
    case firefox = "org.mozilla.firefox"
    case github = "com.github.GitHubClient"
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

    // list apps which we aren't yet able to track, so they're hidden from the Monitored Apps menu
    static let unsupportedAppIds = [String]()

    var category: Category? {
        switch self {
            case .arcbrowser:
                return .browsing
            case .brave:
                return .browsing
            case .canva:
                return .designing
            case .chrome:
                return .browsing
            case .figma:
                return .designing
            case .firefox:
                return .browsing
            case .github:
                return .codereviewing
            case .imessage:
                return .communicating
            case .iterm2:
                return .coding
            case .linear:
                return .planning
            case .notes:
                return .writingdocs
            case .notion:
                return .writingdocs
            case .postman:
                return .debugging
            case .slack:
                return .communicating
            case .safari:
                return .browsing
            case .safaripreview:
                return .browsing
            case .tableplus:
                return .debugging
            case .terminal:
                return .coding
            case .warp:
                return .coding
            case .wecom:
                return .communicating
            case .whatsapp:
                return .meeting
            case .xcode:
                fatalError("\(rawValue) should never use window title")
            case .zoom:
                return .meeting
            case .zed:
                return .coding
        }
    }

    func project(for element: AXUIElement) -> String? {
        // TODO: detect repo from GitHub Desktop Client if possible
        switch self {
            case .slack:
                return extractSuffix(element.rawTitle, separator: " - ", offset: 1)
            case .zed:
                return extractSuffix(element.rawTitle, separator: " — ")
            default:
                guard let url = currentBrowserUrl(for: element) else { return nil }
                return project(from: url)
        }
    }

    private func project(from url: String) -> String? {
        let patterns = [
            "github.com/([^/]+/[^/]+)/?.*$",
            "bitbucket.org/([^/]+/[^/]+)/?.*$",
            "app.circleci.com/.*/?(github|bitbucket|gitlab)/([^/]+/[^/]+)/?.*$",
            "app.travis-ci.com/(github|bitbucket|gitlab)/([^/]+/[^/]+)/?.*$",
            "app.travis-ci.org/(github|bitbucket|gitlab)/([^/]+/[^/]+)/?.*$"
        ]

        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern)
                let nsrange = NSRange(url.startIndex..<url.endIndex, in: url)
                if let match = regex.firstMatch(in: url, options: [], range: nsrange) {
                    // Adjusted to capture the right group based on the pattern.
                    // The group index might be 2 if the pattern includes a platform prefix before the project name.
                    let groupIndex = pattern.contains("(github|bitbucket|gitlab)") ? 2 : 1
                    let range = match.range(at: groupIndex)

                    if range.location != NSNotFound, let range = Range(range, in: url) {
                        return String(url[range])
                    }
                }
            } catch {
                Logging.default.log("Regex error: \(error)")
                continue
            }
        }

        // Return nil if no pattern matches
        return nil
    }

    var language: String? {
        switch self {
            case .figma:
                return "Figma Design"
            case .postman:
                return "HTTP Request"
            default:
                return nil
        }
    }

    func currentBrowserUrl(for element: AXUIElement) -> String? {
        var address: String?
        switch self {
            case .brave:
                let addressField = element.findAddressField()
                address = addressField?.value
            case .chrome:
                let addressField = element.findAddressField()
                address = addressField?.value
            case .firefox:
                let addressField = element.findAddressField()
                address = addressField?.value
            case .linear:
                let projectLabel = element.firstDescendantWhere { $0.value == "Project" }
                let projectButton = projectLabel?.nextSibling?.firstDescendantWhere { $0.role == kAXButtonRole }
                return projectButton?.rawTitle
            case .safari:
                let addressField = element.elementById(identifier: "WEB_BROWSER_ADDRESS_AND_SEARCH_FIELD")
                address = addressField?.value
            case .safaripreview:
                let addressField = element.elementById(identifier: "WEB_BROWSER_ADDRESS_AND_SEARCH_FIELD")
                address = addressField?.value
            default: return nil
        }
        return address
    }

    func entity(for element: AXUIElement, _ app: NSRunningApplication) -> String? {
        if MonitoringManager.isAppBrowser(app) {
            guard
                let url = currentBrowserUrl(for: element),
                FilterManager.filterBrowsedSites(url)
            else { return nil }

            guard PropertiesManager.domainPreference == .domain else { return url }

            return domainFromUrl(url)
        }

        switch self {
            case .canva:
                // Canva obviously implements tabs in a different way than the tab content UI.
                // Due to this circumstance, it's possible to just sample an element from the
                // Canva window which is positioned underneath the tab bar and trace to the
                // web area root which appears to be properly titled. All the UI zoom settings
                // in Canva only change the tab content or sub content of the tab content, hence
                // this should be relatively safe. In cases where this fails, nil should be
                // returned as a consequence of the web area not being found.
                let someElem = element.elementAtPositionRelativeToWindow(x: 10, y: 60)
                let webArea = someElem?.firstAncestorWhere { $0.role == "AXWebArea" }
                return webArea?.rawTitle
            case .notes:
                // There's apparently two text editor implementations in Apple Notes. One uses a web view,
                // the other appears to be a native implementation based on the `ICTK2MacTextView` class.
                let webAreaElement = element.firstDescendantWhere { $0.role == "AXWebArea" }
                if let webAreaElement {
                    // WebView-based implementation
                    let titleElement = webAreaElement.firstDescendantWhere { $0.role == kAXStaticTextRole }
                    return titleElement?.value
                } else {
                    // ICTK2MacTextView
                    let textAreaElement = element.firstDescendantWhere { $0.role == kAXTextAreaRole }
                    if let value = textAreaElement?.value {
                        let title = extractPrefix(value, separator: "\n")
                        return title
                    }
                    return nil
                }
            default:
                return title(for: element)
        }
    }

    func title(for element: AXUIElement) -> String? {
        switch self {
            case .arcbrowser:
                fatalError("\(self.rawValue) should never use window title as entity")
            case .brave:
                fatalError("\(self.rawValue) should never use window title as entity")
            case .canva:
                fatalError("\(self.rawValue) should never use window title as entity")
            case .chrome:
                fatalError("\(self.rawValue) should never use window title as entity")
            case .figma:
                guard
                    let title = extractPrefix(element.rawTitle, separator: " – "),
                    title != "Figma",
                    title != "Drafts"
                else { return nil }
                return title
            case .firefox:
                fatalError("\(self.rawValue) should never use window title as entity")
            case .github:
                return extractPrefix(element.rawTitle, separator: " - ")
            case .imessage:
                return extractPrefix(element.rawTitle, separator: " - ")
            case .iterm2:
                return extractPrefix(element.rawTitle, separator: " - ")
            case .linear:
                return extractPrefix(element.rawTitle, separator: " - ")
            case .notes:
                fatalError("\(self.rawValue) should never use window title as entity")
            case .notion:
                return extractPrefix(element.rawTitle, separator: " - ")
            case .postman:
                guard
                    let title = extractPrefix(element.rawTitle, separator: " - ", fullTitle: true),
                    title != "Postman"
                else { return nil }
                return title
            case .slack:
                return extractPrefix(element.rawTitle, separator: " - ")
            case .safari:
                fatalError("\(self.rawValue) should never use window title as entity")
            case .safaripreview:
                fatalError("\(self.rawValue) should never use window title as entity")
            case .tableplus:
                return extractPrefix(element.rawTitle, separator: " - ")
            case .terminal:
                return extractPrefix(element.rawTitle, separator: " - ")
            case .warp:
                guard
                    let title = extractPrefix(element.rawTitle, separator: " - "),
                    title != "Warp"
                else { return nil }
                return title
            case .wecom:
                return extractPrefix(element.rawTitle, separator: " - ")
            case .whatsapp:
                return extractPrefix(element.rawTitle, separator: " - ")
            case .xcode:
                fatalError("\(self.rawValue) should never use window title as entity")
            case .zoom:
                return extractPrefix(element.rawTitle, separator: " - ")
            case .zed:
                return extractPrefix(element.rawTitle, separator: " — ")
        }
    }

    private func extractPrefix(_ str: String?, separator: String, minCount: Int? = nil, fullTitle: Bool = false) -> String? {
        guard let str = str else { return nil }

        let parts = str.components(separatedBy: separator)
        guard !parts.isEmpty else { return nil }
        guard let item = parts.first else { return nil }

        if let minCount = minCount, minCount > 0, parts.count < minCount {
            return nil
        }

        if item.trimmingCharacters(in: .whitespacesAndNewlines) != "" {
            if fullTitle {
                return str.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return item.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    private func extractSuffix(_ str: String?, separator: String, offset: Int = 0) -> String? {
        guard let str = str else { return nil }

        var parts = str.components(separatedBy: separator)
        guard !parts.isEmpty else { return nil }
        guard parts.count > 1 else { return nil }

        var i = offset
        while i > 0 {
            guard parts.count > 1 else { return nil }

            parts.removeLast()
            i += 1
        }
        guard let item = parts.last else { return nil }

        if item.trimmingCharacters(in: .whitespacesAndNewlines) != "" {
            return item.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }

    private func domainFromUrl(_ url: String) -> String? {
        guard let host = URL(stringWithoutScheme: url)?.host else { return nil }
        let domain = host.replacingOccurrences(of: "^www.", with: "", options: .regularExpression)
        guard let port = URL(stringWithoutScheme: url)?.port else { return domain }
        return "\(domain):\(port)"
    }
}
