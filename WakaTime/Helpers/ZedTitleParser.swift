import Foundation

struct ZedTitleParser {
    struct Result {
        let entity: String?
        let project: String?
    }

    private static let currentTitleOrderVersion = [0, 162, 0]
    private static let separator = " — "

    static func parse(_ title: String?, version: String?) -> Result {
        guard let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return Result(entity: nil, project: nil)
        }

        let projectFirst = usesCurrentTitleOrder(version)
        let options: String.CompareOptions = projectFirst ? [] : .backwards
        guard let separatorRange = title.range(of: separator, options: options) else {
            return Result(entity: nonEmpty(title), project: nil)
        }

        let prefix = nonEmpty(String(title[..<separatorRange.lowerBound]))
        let suffix = nonEmpty(String(title[separatorRange.upperBound...]))
        let entity = projectFirst ? suffix : prefix
        let project = projectFirst ? prefix : suffix

        guard let entity else { return Result(entity: nil, project: nil) }
        return Result(entity: entity, project: entity == project ? nil : project)
    }

    private static func usesCurrentTitleOrder(_ version: String?) -> Bool {
        guard let components = versionComponents(version) else { return true }

        for (component, minimum) in zip(components, currentTitleOrderVersion) where component != minimum {
            return component > minimum
        }

        return true
    }

    private static func versionComponents(_ version: String?) -> [Int]? {
        guard let version = version?.trimmingCharacters(in: .whitespacesAndNewlines), !version.isEmpty else {
            return nil
        }

        let components = version.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count == 3 else { return nil }

        let numbers = components.compactMap { component -> Int? in
            guard !component.isEmpty, component.allSatisfy(\.isASCII), component.allSatisfy(\.isNumber) else {
                return nil
            }
            return Int(component)
        }

        return numbers.count == 3 ? numbers : nil
    }

    private static func nonEmpty(_ component: String) -> String? {
        let component = component.trimmingCharacters(in: .whitespacesAndNewlines)
        return component.isEmpty ? nil : component
    }
}
