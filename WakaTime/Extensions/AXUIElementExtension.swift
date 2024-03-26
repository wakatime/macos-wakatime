import AppKit

struct AXPatternElement {
    var role: String?
    var subrole: String?
    var id: String?
    var title: String?
    var value: String?
    var children: [AXPatternElement] = []
}

extension AXUIElement {
    var selectedText: String? {
        getValue(for: kAXSelectedTextAttribute) as? String
    }

    func getValue(for attribute: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, attribute as CFString, &result) == .success else { return nil }
        return result
    }

    var children: [AXUIElement]? {
        guard let ref = getValue(for: kAXChildrenAttribute) else { return nil }
        return ref as? [AXUIElement]
    }

    var parent: AXUIElement? {
        guard let ref = getValue(for: kAXParentAttribute) else { return nil }
        // swiftlint:disable force_cast
        return (ref as! AXUIElement)
        // swiftlint:enable force_cast
    }

    var nextSibling: AXUIElement? {
        guard let parentChildren = self.parent?.children, let currentIndex = parentChildren.firstIndex(of: self) else { return nil }
        let nextIndex = currentIndex + 1
        guard parentChildren.indices.contains(nextIndex) else { return nil }
        return parentChildren[nextIndex]
    }

    var previousSibling: AXUIElement? {
        guard let parentChildren = self.parent?.children, let currentIndex = parentChildren.firstIndex(of: self) else { return nil }
        let previousIndex = currentIndex - 1
        guard parentChildren.indices.contains(previousIndex) else { return nil }
        return parentChildren[previousIndex]
    }

    var id: String? {
        guard let ref = getValue(for: kAXIdentifierAttribute) else { return nil }
        // swiftlint:disable force_cast
        return (ref as! String)
        // swiftlint:enable force_cast
    }

    var rawTitle: String? {
        guard let ref = getValue(for: kAXTitleAttribute) else { return nil }
        // swiftlint:disable force_cast
        return (ref as! String)
        // swiftlint:enable force_cast
    }

    var role: String? {
        guard let ref = getValue(for: kAXRoleAttribute) else { return nil }
        // swiftlint:disable force_cast
        return (ref as! String)
        // swiftlint:enable force_cast
    }

    var subrole: String? {
        guard let ref = getValue(for: kAXSubroleAttribute) else { return nil }
        // swiftlint:disable force_cast
        return (ref as! String)
        // swiftlint:enable force_cast
    }

    func currentBrowserUrl(for app: MonitoredApp) -> String? {
        var address: String?
        switch app {
            case .brave:
                let addressField = findAddressField()
                address = addressField?.value
            case .chrome:
                let addressField = findAddressField()
                address = addressField?.value
            case .firefox:
                let addressField = findAddressField()
                address = addressField?.value
            case .linear:
                let projectLabel = firstDescendantWhere { $0.value == "Project" }
                let projectButton = projectLabel?.nextSibling?.firstDescendantWhere { $0.role == kAXButtonRole }
                return projectButton?.rawTitle
            case .safari:
                let addressField = elementById(identifier: "WEB_BROWSER_ADDRESS_AND_SEARCH_FIELD")
                address = addressField?.value
            case .safaripreview:
                let addressField = elementById(identifier: "WEB_BROWSER_ADDRESS_AND_SEARCH_FIELD")
                address = addressField?.value
            default: return nil
        }
        return address
    }

    func project(for app: MonitoredApp) -> String? {
        guard let url = currentBrowserUrl(for: app) else { return nil }
        return project(from: url)
    }

    func category(for app: MonitoredApp) -> Category? {
        switch app {
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
                fatalError("\(app.rawValue) should never use window title")
            case .zoom:
                return .meeting
        }
    }

    func language(for app: MonitoredApp) -> String? {
        switch app {
            case .figma:
                return "Figma Design"
            case .postman:
                return "HTTP Request"
            default:
                return nil
        }
    }

    func entity(for monitoredApp: MonitoredApp, _ app: NSRunningApplication) -> String? {
        if MonitoringManager.isAppBrowser(app) {
            guard
                let url = currentBrowserUrl(for: monitoredApp),
                FilterManager.filterBrowsedSites(url)
            else { return nil }

            guard PropertiesManager.domainPreference == .domain else { return url }

            return domainFromUrl(url)
        }

        return title(for: monitoredApp)
    }

    // swiftlint:disable cyclomatic_complexity
    func title(for app: MonitoredApp) -> String? {
        switch app {
            case .arcbrowser:
                fatalError("\(app.rawValue) should never use window title as entity")
            case .brave:
                fatalError("\(app.rawValue) should never use window title as entity")
            case .canva:
                guard
                    let title = extractPrefix(rawTitle, separator: " - ", minCount: 2),
                    title != "Canva",
                    title != "Home"
                else { return nil }
                return title
            case .chrome:
                fatalError("\(app.rawValue) should never use window title as entity")
            case .figma:
                guard
                    let title = extractPrefix(rawTitle, separator: " – "),
                    title != "Figma",
                    title != "Drafts"
                else { return nil }
                return title
            case .firefox:
                fatalError("\(app.rawValue) should never use window title as entity")
            case .imessage:
                guard let title = extractPrefix(rawTitle, separator: " - ") else { return nil }
                return title
            case .iterm2:
                guard let title = extractPrefix(rawTitle, separator: " - ") else { return nil }
                return title
            case .linear:
                guard let title = extractPrefix(rawTitle, separator: " - ") else { return nil }
                return title
            case .notes:
                // There's apparently two text editor implementations in Apple Notes. One uses a web view,
                // the other appears to be a native implementation based on the `ICTK2MacTextView` class.
                let webAreaElement = firstDescendantWhere { $0.role == "AXWebArea" }
                if let webAreaElement {
                    // WebView-based implementation
                    let titleElement = webAreaElement.firstDescendantWhere { $0.role == kAXStaticTextRole }
                    return titleElement?.value
                } else {
                    // ICTK2MacTextView
                    let textAreaElement = firstDescendantWhere { $0.role == kAXTextAreaRole }
                    if let value = textAreaElement?.value {
                        let title = extractPrefix(value, separator: "\n")
                        return title
                    }
                    return nil
                }
            case .notion:
                guard let title = extractPrefix(rawTitle, separator: " - ") else { return nil }
                return title
            case .postman:
                guard
                    let title = extractPrefix(rawTitle, separator: " - ", fullTitle: true),
                    title != "Postman"
                else { return nil }

                return title
            case .slack:
                guard let title = extractPrefix(rawTitle, separator: " - ") else { return nil }
                return title
            case .safari:
                fatalError("\(app.rawValue) should never use window title as entity")
            case .safaripreview:
                fatalError("\(app.rawValue) should never use window title as entity")
            case .tableplus:
                guard let title = extractPrefix(rawTitle, separator: " - ") else { return nil }
                return title
            case .terminal:
                guard let title = extractPrefix(rawTitle, separator: " - ") else { return nil }
                return title
            case .warp:
                guard
                    let title = extractPrefix(rawTitle, separator: " - "),
                    title != "Warp"
                else { return nil }
                return title
            case .wecom:
                guard let title = extractPrefix(rawTitle, separator: " - ") else { return nil }
                return title
            case .whatsapp:
                guard let title = extractPrefix(rawTitle, separator: " - ") else { return nil }
                return title
            case .xcode:
                fatalError("\(app.rawValue) should never use window title as entity")
            case .zoom:
                guard let title = extractPrefix(rawTitle, separator: " - ") else { return nil }
                return title
        }
    }
    // swiftlint:enable cyclomatic_complexity

    var document: String? {
        guard let ref = getValue(for: kAXDocumentAttribute) else { return nil }
        // swiftlint:disable force_cast
        return (ref as! String)
        // swiftlint:enable force_cast
    }

    var value: String? {
        guard let ref = getValue(for: kAXValueAttribute) else { return nil }
        return (ref as? String)
    }

    var activeWindow: AXUIElement? {
        // swiftlint:disable force_cast
        if let window = getValue(for: kAXFocusedWindowAttribute) {
            return (window as! AXUIElement)
        }
        if let window = getValue(for: kAXMainWindowAttribute) {
            return (window as! AXUIElement)
        }
        if let window = getValue(for: kAXWindowAttribute) {
            return (window as! AXUIElement)
        }
        // swiftlint:enable force_cast
        return nil
    }

    var currentPath: URL? {
        if let window = activeWindow {
            if let path = window.document {
                if path.hasPrefix("file://") {
                    return URL(string: path.dropFirst(7).description)
                }
                return URL(string: path)
            }
        }
        if let path = document {
            if path.hasPrefix("file://") {
                return URL(string: path.dropFirst(7).description)
            }
            return URL(string: path)
        }
        return nil
    }

    func domainFromUrl(_ url: String) -> String? {
        guard let host = URL(string: url)?.host else { return nil }
        let domain = host.replacingOccurrences(of: "^www.", with: "", options: .regularExpression)
        guard let port = URL(string: url)?.port else { return domain }
        return "\(domain):\(port)"
    }

    // Traverses the element's subtree (breadth-first) until visitor() returns false or traversal is completed
    func traverseDown(visitor: (AXUIElement) -> Bool) {
        var queue: [AXUIElement] = [self]
        while !queue.isEmpty {
            let currentElement = queue.removeFirst()
            if let children = currentElement.children {
                for child in children {
                    if !visitor(child) { return }
                    queue.append(child)
                }
            }
        }
    }

    func traverseDownDFS(visitor: (AXUIElement) -> Bool) {
        var stack: [AXUIElement] = [self]
        while !stack.isEmpty {
            let currentElement = stack.removeLast()
            if !visitor(currentElement) { return }
            if let children = currentElement.children {
                stack.append(contentsOf: children.reversed())
            }
        }
    }

    // Traverses the element's subtree (breadth-first) until visitor() returns false or traversal is completed
    func traverseUp(visitor: (AXUIElement) -> Bool, element: AXUIElement? = nil) {
        let element = element ?? self
        if let parent = element.parent {
            if !visitor(parent) { return }
            traverseUp(visitor: visitor, element: parent)
        }
    }

    func firstDescendantWhere(_ condition: (AXUIElement) -> Bool) -> AXUIElement? {
        var matchingDescendant: AXUIElement?
        traverseDownDFS { element in
            if condition(element) {
                matchingDescendant = element
                return false // stop traversal
            }
            return true // continue traversal
        }
        return matchingDescendant
    }

    // Find the first descendant whose identifier matches the given identifier
    func elementById(identifier: String) -> AXUIElement? {
        firstDescendantWhere { $0.id == identifier }
    }

    func firstAncestorWhere(_ condition: (AXUIElement) -> Bool) -> AXUIElement? {
        var matchingAncestor: AXUIElement?
        traverseUp { element in
            if condition(element) {
                matchingAncestor = element
                return false
            }
            return true
        }
        return matchingAncestor
    }

    // Index path of `element` relative to self
    func indexPath(for element: AXUIElement) -> [Int] {
        var path = [Int]()
        var currentElement: AXUIElement? = element

        while let current = currentElement, current != self {
            if let parent = current.parent {
                if let index = parent.children?.firstIndex(where: { $0 == current }) {
                    path.insert(index, at: 0)
                }
                currentElement = parent
            } else {
                // No parent found, stop the loop
                break
            }
        }

        return path
    }

    // Finds the element at the given `indexPath`. `indexPath` must be relative to self.
    // If no element with the given index path exists, returns nil.
    func elementAtIndexPath(_ indexPath: [Int]) -> AXUIElement? {
        var currentElement: AXUIElement = self
        for index in indexPath {
            // currentElement.debugPrint()
            guard let children = currentElement.children, index < children.count else {
                // Index is out of bounds for the current element's children
                return nil
            }
            currentElement = children[index]
        }
        return currentElement
    }

    func findByPattern(_ pattern: AXPatternElement, within element: AXUIElement? = nil) -> AXUIElement? {
        let rootElement = element ?? self

        func matchesPattern(element: AXUIElement, pattern: AXPatternElement) -> Bool {
            let roleMatches = pattern.role == nil || element.role == pattern.role
            let subroleMatches = pattern.subrole == nil || element.subrole == pattern.subrole
            let titleMatches = pattern.title == nil || element.rawTitle == pattern.title
            let valueMatches = pattern.value == nil || element.selectedText == pattern.value
            let idMatches = pattern.id == nil || element.id == pattern.id

            return roleMatches && subroleMatches && titleMatches && valueMatches && idMatches
        }

        func search(element: AXUIElement, pattern: AXPatternElement) -> AXUIElement? {
            if matchesPattern(element: element, pattern: pattern) {
                var currentElement = element
                for childPattern in pattern.children {
                    guard let children = currentElement.children else { return nil }

                    var foundMatch = false
                    for child in children {
                        if let match = search(element: child, pattern: childPattern) {
                            currentElement = match
                            foundMatch = true
                            break
                        }
                    }
                    if !foundMatch {
                        return nil
                    }
                }
                return currentElement
            } else {
                guard let children = element.children else { return nil }

                for child in children {
                    if let match = search(element: child, pattern: pattern) {
                        return match
                    }
                }
            }
            return nil
        }

        return search(element: rootElement, pattern: pattern)
    }

    // Finds the first text area element whose value looks like a URL. Note that Chrome
    // cuts off the URL scheme, so this only scans for a domain with an optional path.
    func findAddressField() -> AXUIElement? {
        firstDescendantWhere { descendant in
            if descendant.role == kAXTextFieldRole, let value = descendant.value {
                let pattern = "(([^:\\/\\s]+)\\.([^:\\/\\s\\.]+))(\\/\\w+)*(\\/([\\w\\-\\.]+[^#?\\s]+))?(.*)?(#[\\w\\-]+)?$"
                do {
                    let regex = try NSRegularExpression(pattern: pattern)
                    let range = NSRange(value.startIndex..<value.endIndex, in: value)
                    let matches = regex.numberOfMatches(in: value, options: [], range: range)
                    return matches > 0
                } catch {
                    // print("Regex error: \(error.localizedDescription)")
                    return false
                }
            }
            return  false
        }
    }

    func debugPrintSubtree(element: AXUIElement? = nil, depth: Int = 0, highlight indexPath: [Int] = [], currentPath: [Int] = []) {
        let element = element ?? self
        if let children = element.children {
            for (index, child) in children.enumerated() {
                let indentation = String(repeating: " ", count: depth)
                let isMultiline = child.value?.contains("\n") ?? false
                let displayValue = isMultiline ? "[multiple lines]" : (child.value?.components(separatedBy: .newlines).first ?? "?")
                let ellipsedValue = displayValue.count > 50 ? String(displayValue.prefix(47)) + "..." : displayValue

                // Check if the current path matches the ancestry path
                let isOnIndexPath = currentPath + [index] == indexPath.prefix(currentPath.count + 1)
                let highlightIndicator = isOnIndexPath ? "→ " : "  "

                print(
                    "\(indentation)\(highlightIndicator)Role: \"\(child.role ?? "[undefined]")\", " +
                    "Subrole: \(child.subrole ?? "<nil>"), " +
                    "Id: \(id ?? "<nil>"), " +
                    "Title: \(child.rawTitle ?? "<nil>"), " +
                    "Value: \"\(ellipsedValue)\""
                )

                debugPrintSubtree(element: child, depth: depth + 1, highlight: indexPath, currentPath: currentPath + [index])
            }
        }
    }

    func debugPrintAncestors() {
        traverseUp { element in
            let title = element.rawTitle ?? "<nil>"
            let role = element.role ?? "<nil>"
            let subrole = element.subrole ?? "<nil>"
            print("Title: \(title), Role: \(role), Subrole: \(subrole)")
            return true // Continue traversing up
        }
    }

    func debugPrint() {
        let isMultiline = value?.contains("\n") ?? false
        let displayValue = isMultiline ? "[multiple lines]" : (value?.components(separatedBy: .newlines).first ?? "?")
        let ellipsedValue = displayValue.count > 50 ? String(displayValue.prefix(47)) + "..." : displayValue
        print(
            "Role: \(role ?? "<nil>"), " +
            "Subrole: \(subrole ?? "<nil>"), " +
            "Id: \(id ?? "<nil>"), " +
            "Title: \(rawTitle ?? "<nil>"), " +
            "Value: \"\(ellipsedValue)\""
        )
    }

    private func extractPrefix(_ str: String?, separator: String, minCount: Int? = nil, fullTitle: Bool = false) -> String? {
        guard let str = str else { return nil }

        let parts = str.components(separatedBy: separator)

        if let minCount = minCount, minCount > 0, parts.count < minCount {
            return nil
        }

        if !parts.isEmpty && parts[0].trimmingCharacters(in: .whitespacesAndNewlines) != "" {
            if fullTitle {
                return str.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
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
}

enum AXUIElementNotification {
    case selectedTextChanged
    case focusedUIElementChanged
    case focusedWindowChanged
    case valueChanged
    case uknown

    static func notificationFrom(string notification: String) -> AXUIElementNotification {
        switch notification {
            case "AXSelectedTextChanged":
                return .selectedTextChanged
            case "AXFocusedUIElementChanged":
                return .focusedUIElementChanged
            case "AXFocusedWindowChanged":
                return .focusedWindowChanged
            case "AXValueChanged":
                return .valueChanged
            default:
                return .uknown
        }
    }
}
