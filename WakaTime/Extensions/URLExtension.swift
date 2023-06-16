import Foundation

extension URL {
    // Implements foward-compat for macOS 13's URL.formatted
    func formatted() -> String {
        let components = URLComponents(url: self, resolvingAgainstBaseURL: true)
        let path = components?.path ?? ""
        return path.replacingOccurrences(of: " ", with: "\\ ")
    }
}
