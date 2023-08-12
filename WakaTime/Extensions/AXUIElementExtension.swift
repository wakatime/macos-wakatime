import AppKit

extension AXUIElement {
    var selectedText: String? {
        rawValue(for: kAXSelectedTextAttribute) as? String
    }

    func rawValue(for attribute: String) -> AnyObject? {
        var rawValue: AnyObject?
        let error = AXUIElementCopyAttributeValue(self, attribute as CFString, &rawValue)
        return error == .success ? rawValue : nil
    }

    func getValue(for attribute: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, attribute as CFString, &result) == .success else { return nil }
        return result
    }

    var children: [AXUIElement]? {
        guard let rawChildren = rawValue(for: kAXChildrenAttribute) else { return nil }
        return rawChildren as? [AXUIElement]
    }

    // Traverses the element's subtree (breadth-first) until visitor() returns false or traversal is completed
    func traverse(visitor: (AXUIElement) -> Bool, element: AXUIElement? = nil) {
        let element = element ?? self
        if let children = element.children {
            for child in children {
                if !visitor(child) { return }
                traverse(visitor: visitor, element: child)
            }
        }
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
