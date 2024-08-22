import Cocoa
import Foundation

class MonitoringManager {
    enum MonitoringState {
        case on
        case off
    }

    static func isAppMonitored(for bundleId: String) -> Bool {
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
            let activeWindow = AXUIElementCreateApplication(pid).activeWindow,
            let entity = entity(for: app, activeWindow),
            let entityUnwrapped = entity.0
        else { return nil }

        return HeartbeatData(
            entity: entityUnwrapped,
            entityType: entity.1,
            project: project(for: app, activeWindow),
            language: language(for: app),
            category: category(for: app)
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

    static func entity(for app: NSRunningApplication, _ element: AXUIElement) -> (String?, EntityType)? {
        if MonitoringManager.isAppBrowser(app) {
            guard
                let url = currentBrowserUrl(for: app, element),
                FilterManager.filterBrowsedSites(url)
            else { return nil }

            guard PropertiesManager.domainPreference == .domain else { return (url, .url) }

            return (domainFromUrl(url), .domain)
        }

        guard let monitoredApp = app.monitoredApp else { return (title(for: app, element), .app) }

        switch monitoredApp {
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
                return (webArea?.rawTitle, .app)
            case .notes:
                // There's apparently two text editor implementations in Apple Notes. One uses a web view,
                // the other appears to be a native implementation based on the `ICTK2MacTextView` class.
                let webAreaElement = element.firstDescendantWhere { $0.role == "AXWebArea" }
                if let webAreaElement {
                    // WebView-based implementation
                    let titleElement = webAreaElement.firstDescendantWhere { $0.role == kAXStaticTextRole }
                    return (titleElement?.value, .app)
                } else {
                    // ICTK2MacTextView
                    let textAreaElement = element.firstDescendantWhere { $0.role == kAXTextAreaRole }
                    if let value = textAreaElement?.value {
                        let title = extractPrefix(value, separator: "\n")
                        return (title, .app)
                    }
                    return nil
                }
            default:
                return (title(for: app, element), .app)
        }
    }

    static func title(for app: NSRunningApplication, _ element: AXUIElement) -> String? {
        guard let monitoredApp = app.monitoredApp else {
            return extractPrefix(element.rawTitle, separator: " — ")
        }

        switch monitoredApp {
            case .arcbrowser:
                fatalError("\(monitoredApp.rawValue) should never use window title as entity")
            case .brave:
                fatalError("\(monitoredApp.rawValue) should never use window title as entity")
            case .canva:
                fatalError("\(monitoredApp.rawValue) should never use window title as entity")
            case .chrome:
                fatalError("\(monitoredApp.rawValue) should never use window title as entity")
            case .figma:
                guard
                    let title = extractPrefix(element.rawTitle, separator: " – "),
                    title != "Figma",
                    title != "Drafts"
                else { return nil }
                return title
            case .firefox:
                fatalError("\(monitoredApp.rawValue) should never use window title as entity")
            case .github:
                return extractPrefix(element.rawTitle, separator: " - ")
            case .imessage:
                return extractPrefix(element.rawTitle, separator: " - ")
            case .iterm2:
                return extractPrefix(element.rawTitle, separator: " - ")
            case .linear:
                return extractPrefix(element.rawTitle, separator: " - ")
            case .notes:
                fatalError("\(monitoredApp.rawValue) should never use window title as entity")
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
                fatalError("\(monitoredApp.rawValue) should never use window title as entity")
            case .safaripreview:
                fatalError("\(monitoredApp.rawValue) should never use window title as entity")
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
                fatalError("\(monitoredApp.rawValue) should never use window title as entity")
            case .zoom:
                return extractPrefix(element.rawTitle, separator: " - ")
            case .zed:
                return extractPrefix(element.rawTitle, separator: " — ")
        }
    }

    static func category(for app: NSRunningApplication) -> Category? {
        guard let monitoredApp = app.monitoredApp else { return .coding }

        switch monitoredApp {
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
                fatalError("\(monitoredApp.rawValue) should never use window title")
            case .zoom:
                return .meeting
            case .zed:
                return .coding
        }
    }

    static func project(for app: NSRunningApplication, _ element: AXUIElement) -> String? {
        guard let monitoredApp = app.monitoredApp else {
            guard let url = currentBrowserUrl(for: app, element) else { return nil }
            return project(from: url)
        }

        // TODO: detect repo from GitHub Desktop Client if possible
        switch monitoredApp {
            case .slack:
                return extractSuffix(element.rawTitle, separator: " - ", offset: 1)
            case .zed:
                return extractSuffix(element.rawTitle, separator: " — ")
            default:
                guard let url = currentBrowserUrl(for: app, element) else { return nil }
                return project(from: url)
        }
    }

    static func project(from url: String) -> String? {
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

    static func language(for app: NSRunningApplication) -> String? {
        guard let monitoredApp = app.monitoredApp else { return nil }

        switch monitoredApp {
            case .figma:
                return "Figma Design"
            case .postman:
                return "HTTP Request"
            default:
                return nil
        }
    }

    static func currentBrowserUrl(for app: NSRunningApplication, _ element: AXUIElement) -> String? {
        guard let monitoredApp = app.monitoredApp else { return nil }

        var address: String?
        switch monitoredApp {
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

    static func extractPrefix(_ str: String?, separator: String, minCount: Int? = nil, fullTitle: Bool = false) -> String? {
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

    static func extractSuffix(_ str: String?, separator: String, offset: Int = 0) -> String? {
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

    static func domainFromUrl(_ url: String) -> String? {
        guard let host = URL(stringWithoutScheme: url)?.host else { return nil }
        let domain = host.replacingOccurrences(of: "^www.", with: "", options: .regularExpression)
        guard let port = URL(stringWithoutScheme: url)?.port else { return domain }
        return "\(domain):\(port)"
    }
}

struct HeartbeatData {
    var entity: String
    var entityType: EntityType
    var project: String?
    var language: String?
    var category: Category?
}
