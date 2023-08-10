import AppKit

class Accessibility {
    public static func requestA11yPermission() -> Bool {
        let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options: NSDictionary = [prompt: true]
        let appHasPermission = AXIsProcessTrustedWithOptions(options)
        return appHasPermission
    }
}
