import AppKit

class Accessibility {
    public static func requestA11yPermission() {
        let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options: NSDictionary = [prompt: true]
        let appHasPermission = AXIsProcessTrustedWithOptions(options)
        if appHasPermission {
            // print("has a11y permission")
        }
    }
}
