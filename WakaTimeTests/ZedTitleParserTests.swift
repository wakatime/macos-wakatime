import XCTest
@testable import WakaTime

final class ZedTitleParserTests: XCTestCase {
    func testUsesLegacyTitleOrderBeforeVersionZeroPointOneSixtyTwo() {
        let result = ZedTitleParser.parse("main.swift — sample-project", version: "0.161.2")

        XCTAssertEqual(result.entity, "main.swift")
        XCTAssertEqual(result.project, "sample-project")
    }

    func testUsesCurrentTitleOrderFromVersionZeroPointOneSixtyTwo() {
        let result = ZedTitleParser.parse("sample-project — main.swift", version: "0.162.0")

        XCTAssertEqual(result.entity, "main.swift")
        XCTAssertEqual(result.project, "sample-project")
    }

    func testDefaultsToCurrentTitleOrderWhenVersionIsUnavailableOrInvalid() {
        for version in [nil, "unknown", "0.161.2junk", "0.161.2.3"] as [String?] {
            let result = ZedTitleParser.parse("sample-project — main.swift", version: version)

            XCTAssertEqual(result.entity, "main.swift")
            XCTAssertEqual(result.project, "sample-project")
        }
    }

    func testDoesNotUseEntityAsProjectForAmbiguousTitle() {
        let result = ZedTitleParser.parse("main.swift — main.swift", version: "1.10.3")

        XCTAssertEqual(result.entity, "main.swift")
        XCTAssertNil(result.project)
    }

    func testKeepsSingleComponentTitleAsEntityWithoutProject() {
        let result = ZedTitleParser.parse("main.swift", version: "1.10.3")

        XCTAssertEqual(result.entity, "main.swift")
        XCTAssertNil(result.project)
    }

    func testDoesNotReturnAProjectWithoutAnEntity() {
        let current = ZedTitleParser.parse("sample-project — ", version: "1.10.3")
        let legacy = ZedTitleParser.parse(" — sample-project", version: "0.161.2")

        XCTAssertNil(current.entity)
        XCTAssertNil(current.project)
        XCTAssertNil(legacy.entity)
        XCTAssertNil(legacy.project)
    }

    func testPreservesSeparatorsInsideEntity() {
        let current = ZedTitleParser.parse("sample-project — foo — bar.swift", version: "1.10.3")
        let legacy = ZedTitleParser.parse("foo — bar.swift — sample-project", version: "0.161.2")

        XCTAssertEqual(current.entity, "foo — bar.swift")
        XCTAssertEqual(current.project, "sample-project")
        XCTAssertEqual(legacy.entity, "foo — bar.swift")
        XCTAssertEqual(legacy.project, "sample-project")
    }
}
