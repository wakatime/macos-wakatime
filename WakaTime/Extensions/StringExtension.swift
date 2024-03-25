import Foundation

extension String {
    func matchesRegex(_ pattern: String) -> Bool {
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(location: 0, length: self.utf16.count)
            return regex.firstMatch(in: self, options: [], range: range) != nil
        }
        return false
    }

    func trim() -> String {
        self.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
}
