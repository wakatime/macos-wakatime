import AppKit

// The api key field. NSSecureTextField shows the key as dots and refuses copy and cut, so only
// paste, select all, undo and redo are passed on, the same shortcuts WKTextField handles.
class WKSecureTextField: NSSecureTextField {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.type == NSEvent.EventType.keyDown {
            let modifierFlags = event.modifierFlags.rawValue & NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue
            if modifierFlags == NSEvent.ModifierFlags.command.rawValue {
                switch event.charactersIgnoringModifiers?.first {
                    case "v":
                        if NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self) { return true }
                    case "a":
                        if NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: self) { return true }
                    case "z":
                        if NSApp.sendAction(Selector(("undo:")), to: nil, from: self) { return true }
                    default:
                        break
                }
            } else if modifierFlags == NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue {
                if NSApp.sendAction(Selector(("redo:")), to: nil, from: self) { return true }
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}
