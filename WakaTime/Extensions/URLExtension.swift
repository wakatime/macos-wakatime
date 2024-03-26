import Foundation

extension URL {
    init?(stringWithoutScheme string: String) {
        if string.starts(with: "https?://") {
            self.init(string: string)
        } else {
            self.init(string: "https://\(string)")
        }
    }
}
