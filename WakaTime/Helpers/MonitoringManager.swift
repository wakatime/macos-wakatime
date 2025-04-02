import Cocoa
import Foundation

class MonitoringManager {
    enum MonitoringState {
        case on
        case off
    }

    static func isAppMonitored(for bundleId: String) -> Bool {
        allMonitoredApps.contains(bundleId)
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

        let project = project(for: app, activeWindow)
        var language = language(for: app, activeWindow)
        if project != nil && language == nil {
            language = "<<LAST_LANGUAGE>>"
        }

        let heartbeat = HeartbeatData(
            entity: entityUnwrapped,
            entityType: entity.1,
            project: project,
            language: language,
            category: category(for: app, activeWindow)
        )
        return heartbeat
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

    static var allMonitoredApps: [String] {
        if let bundleIds = UserDefaults.standard.stringArray(forKey: monitoringKey) {
            return bundleIds
        } else {
            var bundleIds: [String] = []
            let defaults = UserDefaults.standard.dictionaryRepresentation()
            for key in defaults.keys {
                if key.starts(with: "is_") && key.contains("_monitored") {
                    if UserDefaults.standard.bool(forKey: key) {
                        let bundleId = key.replacingOccurrences(of: "is_", with: "").replacingOccurrences(of: "_monitored", with: "")
                        bundleIds.append(bundleId)
                    }
                    UserDefaults.standard.removeObject(forKey: key)
                }
            }
            UserDefaults.standard.set(bundleIds, forKey: monitoringKey)
            UserDefaults.standard.synchronize()
            return bundleIds
        }
    }

    static func set(monitoringState: MonitoringState, for bundleId: String) {
        if monitoringState == .on {
            UserDefaults.standard.set(Array(Set(allMonitoredApps + [bundleId])), forKey: monitoringKey)
        } else {
            let apps = allMonitoredApps.filter { $0 != bundleId }
            UserDefaults.standard.set(apps, forKey: monitoringKey)
        }
        UserDefaults.standard.synchronize()
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

    static var monitoringKey = "wakatime_monitored_apps"

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

    // swiftlint:disable cyclomatic_complexity
    static func title(for app: NSRunningApplication, _ element: AXUIElement) -> String? {
        guard let monitoredApp = app.monitoredApp else {
            return extractPrefix(element.rawTitle)
        }

        switch monitoredApp {
            case .adobeaftereffect:
                return extractPrefix(element.rawTitle)
            case .adobebridge:
                return extractPrefix(element.rawTitle)
            case .adobeillustrator:
                return extractPrefix(element.rawTitle)
            case .adobemediaencoder:
                return extractPrefix(element.rawTitle)
            case .adobephotoshop:
                return extractPrefix(element.rawTitle)
            case .adobepremierepro:
                return extractPrefix(element.rawTitle)
            case .arcbrowser:
                fatalError("\(monitoredApp.rawValue) should never use window title as entity")
            case .beeper:
                return extractPrefix(element.rawTitle)
            case .brave:
                fatalError("\(monitoredApp.rawValue) should never use window title as entity")
            case .canva:
                fatalError("\(monitoredApp.rawValue) should never use window title as entity")
            case .chrome, .chromebeta, .chromecanary:
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
            case .miro:
                return extractSuffix(element.rawTitle)
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
            case .rocketchat:
                return extractPrefix(element.rawTitle)
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

    static func category(for app: NSRunningApplication, _ element: AXUIElement) -> Category {
        guard let monitoredApp = app.monitoredApp else {
            guard let url = currentBrowserUrl(for: app, element) else { return .coding }
            return category(from: url)
        }

        switch monitoredApp {
            case .adobeaftereffect:
                return .designing
            case .adobebridge:
                return .designing
            case .adobeillustrator:
                return .designing
            case .adobemediaencoder:
                return .designing
            case .adobephotoshop:
                return .designing
            case .adobepremierepro:
                return .designing
            case .arcbrowser:
                return .browsing
            case .beeper:
                return .communicating
            case .brave:
                return .browsing
            case .canva:
                return .designing
            case .chrome, .chromebeta, .chromecanary:
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
            case .miro:
                return .planning
            case .notes:
                return .writingdocs
            case .notion:
                return .writingdocs
            case .postman:
                return .debugging
            case .rocketchat:
                return .communicating
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
    // swiftlint:enable cyclomatic_complexity

    static func category(from url: String) -> Category {
        let patterns = [
            "github.com/[^/]+/[^/]+/pull/.*$",
            "gitlab.com/[^/]+/[^/]+/[^/]+/merge_requests/.*$",
            "bitbucket.org/[^/]+/[^/]+/pull-requests/.*$",
        ]

        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern)
                let nsrange = NSRange(url.startIndex..<url.endIndex, in: url)
                if regex.firstMatch(in: url, options: [], range: nsrange) != nil {
                    return .codereviewing
                }
            } catch {
                Logging.default.log("Regex error: \(error)")
                continue
            }
        }

        return .coding
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

    struct Pattern {
        var expression: String
        var group: Int
    }

    static func project(from url: String) -> String? {
        let patterns: [Pattern] = [
            Pattern(expression: "github.com/[^/]+/([^/]+)/?.*$", group: 1),
            Pattern(expression: "gitlab.com/[^/]+/([^/]+)/?.*$", group: 1),
            Pattern(expression: "bitbucket.org/[^/]+/([^/]+)/?.*$", group: 1),
            Pattern(expression: "app.circleci.com/.*/?(github|bitbucket|gitlab)/[^/]+/([^/]+)/?.*$", group: 2),
            Pattern(expression: "app.travis-ci.com/(github|bitbucket|gitlab)/[^/]+/([^/]+)/?.*$", group: 2),
            Pattern(expression: "app.travis-ci.org/(github|bitbucket|gitlab)/[^/]+/([^/]+)/?.*$", group: 2)
        ]

        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern.expression)
                let nsrange = NSRange(url.startIndex..<url.endIndex, in: url)
                if let match = regex.firstMatch(in: url, options: [], range: nsrange) {
                    // Adjusted to capture the right group based on the pattern.
                    // The group index might be 2 if the pattern includes a platform prefix before the project name.
                    let range = match.range(at: pattern.group)

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

    static func language(for app: NSRunningApplication, _ element: AXUIElement) -> String? {
        guard let monitoredApp = app.monitoredApp else { return nil }

        switch monitoredApp {
            case .canva:
                return "Image (svg)"
            case .chrome, .chromebeta, .chromecanary:
                do {
                    guard let url = currentBrowserUrl(for: app, element) else { return nil }

                    let regex = try NSRegularExpression(pattern: "github.com/[^/]+/[^/]+/?$")
                    let nsrange = NSRange(url.startIndex..<url.endIndex, in: url)
                    if regex.firstMatch(in: url, options: [], range: nsrange) != nil {
                        let languages = element.firstDescendantWhere { $0.role == "AXStaticText" && $0.value == "Languages" }
                        guard let languages = languages else { return nil }

                        guard let wrapper = languages.parent?.parent else { return nil }

                        let langList = wrapper.firstDescendantWhere { $0.role == "AXList" }
                        guard let langList = langList else { return nil }

                        let link = langList.firstDescendantWhere { $0.role == "AXLink" }
                        guard let link = link else { return nil }

                        let lang = link.firstDescendantWhere { $0.role == "AXStaticText" }
                        guard let lang = lang else { return nil }

                        return lang.value
                    }

                    return nil
                } catch {
                    Logging.default.log("Error parsing language from browser: \(error)")
                    return nil
                }
            case .figma:
                return "Image (svg)"
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
            case .arcbrowser:
                let addressField = element.findAddressField()
                address = addressField?.value
            case .brave:
                let addressField = element.findAddressField()
                address = addressField?.value
            case .chrome, .chromebeta, .chromecanary:
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

    static func extractPrefix(_ str: String?, separator: String? = nil, minCount: Int? = nil, fullTitle: Bool = false) -> String? {
        guard let str = str else { return nil }

        guard let separator = separator else {
            return getFirstPrefixMatch(str)
        }

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

    static func extractSuffix(_ str: String?, separator: String? = nil, offset: Int = 0) -> String? {
        guard let str = str else { return nil }

        guard let separator = separator else {
            return getFirstSuffixMatch(str)
        }

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

    static let separators = [
        "-",
        "᠆",
        "‐",
        "‑",
        "‒",
        "–",
        "—",
        "―",
        "⸺",
        "⸻",
        "︱",
        "︲",
        "﹘",
        "﹣",
        "－",
    ]

    static func getFirstPrefixMatch(_ str: String) -> String {
        guard !str.isEmpty else { return str.trimmingCharacters(in: .whitespacesAndNewlines) }

        for separator in separators {
            let parts = str.components(separatedBy: separator)
            guard parts.count > 1 else { continue }
            guard let item = parts.first else { continue }

            let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            return trimmed
        }

        return str.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func getFirstSuffixMatch(_ str: String) -> String {
        guard !str.isEmpty else { return str.trimmingCharacters(in: .whitespacesAndNewlines) }

        for separator in separators {
            let parts = str.components(separatedBy: separator)
            guard parts.count > 1 else { continue }
            guard let item = parts.last else { continue }

            let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            return trimmed
        }

        return str.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct HeartbeatData {
    var entity: String
    var entityType: EntityType
    var project: String?
    var language: String?
    var category: Category?
}
