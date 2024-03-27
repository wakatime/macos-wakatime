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

    func elementAtPosition(x: Float, y: Float) -> AXUIElement? {
        var element: AXUIElement?
        AXUIElementCopyElementAtPosition(self, x, y, &element)
        return element
    }

    func elementAtPositionRelativeToWindow(x: CGFloat, y: CGFloat) -> AXUIElement? {
        // swiftlint:disable force_unwrapping
        let windowPositionData = getValue(for: kAXPositionAttribute)!
        let windowSizeData = getValue(for: kAXSizeAttribute)!
        // swiftlint:enable force_unwrapping

        var windowPosition = CGPoint()
        var windowSize = CGSize()

        // swiftlint:disable force_cast
        if !AXValueGetValue(windowPositionData as! AXValue, .cgPoint, &windowPosition) ||
           !AXValueGetValue(windowSizeData as! AXValue, .cgSize, &windowSize) {
            return nil
        }
        // swiftlint:enable force_cast

        let globalX = windowPosition.x + x
        let globalY = windowPosition.y + y

        if globalX < windowPosition.x || globalX > windowPosition.x + windowSize.width ||
           globalY < windowPosition.y || globalY > windowPosition.y + windowSize.height {
            // Point is outside the window bounds
            return nil
        }

        var element: AXUIElement?
        let systemWideElement = AXUIElementCreateSystemWide()
        AXUIElementCopyElementAtPosition(systemWideElement, Float(globalX), Float(globalY), &element)
        return element
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

    func extractPrefix(_ str: String?, separator: String, minCount: Int? = nil, fullTitle: Bool = false) -> String? {
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
