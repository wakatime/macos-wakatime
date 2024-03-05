import AppKit

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

    // swiftlint:disable cyclomatic_complexity
    func title(for app: MonitoredApp) -> String? {
        switch app {
            case .arcbrowser:
                guard
                    let title = extractPrefix(rawTitle, separator: " - "),
                    title != "Arc"
                else { return nil }
                return title
            case .canva:
                guard
                    let title = extractPrefix(rawTitle, separator: " - ", minCount: 2),
                    title != "Canva",
                    title != "Home"
                else { return nil }
                return title
            case .chrome:
                guard
                    let title = extractPrefix(rawTitle, separator: " - "),
                    title != "Chrome",
                    title != "New Tab"
                else { return nil }
                return title
            case .figma:
                guard
                    let title = extractPrefix(rawTitle, separator: " – "),
                    title != "Figma",
                    title != "Drafts"
                else { return nil }
                return title
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
                let webAreaElement = firstDescendantWhere { $0.role == "AXWebArea" }
                let titleElement = webAreaElement?.firstDescendantWhere { $0.role == kAXStaticTextRole }
                return titleElement?.value
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
                guard
                    let title = extractPrefix(rawTitle, separator: " - "),
                    title != "Safari"
                else { return nil }
                return title
            case .safaripreview:
                guard
                    let title = extractPrefix(rawTitle, separator: " - "),
                    title != "Safari",
                    title != "Safari Technology Preview"
                else { return nil }
                return title
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

    func debugPrintSubtree(element: AXUIElement? = nil, depth: Int = 0) {
        let element = element ?? self
        if let children = element.children {
            for child in children {
                let indentation = String(repeating: " ", count: depth)
                let isMultiline = child.value?.contains("\n") ?? false
                let displayValue = isMultiline ? "[multiple lines]" : (child.value?.components(separatedBy: .newlines).first ?? "?")
                let ellipsedValue = displayValue.count > 50 ? String(displayValue.prefix(47)) + "..." : displayValue
                print(
                    "\(indentation)Role: \(child.role ?? "?"), " +
                    "Subrole: \(child.subrole ?? "?"), " +
                    "Title: \(child.rawTitle ?? "?"), " +
                    "Value: \(ellipsedValue)"
                )
                debugPrintSubtree(element: child, depth: depth + 1)
            }
        }
    }

    func debugPrint() {
        let isMultiline = value?.contains("\n") ?? false
        let displayValue = isMultiline ? "[multiple lines]" : (value?.components(separatedBy: .newlines).first ?? "?")
        let ellipsedValue = displayValue.count > 50 ? String(displayValue.prefix(47)) + "..." : displayValue
        print(
            "Role: \(role ?? "?"), " +
            "Subrole: \(subrole ?? "?"), " +
            "Title: \(rawTitle ?? "?"), " +
            "Value: \(ellipsedValue)"
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
