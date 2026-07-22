import XCTest
@testable import WakaTime

final class ZedTitleParserTests: XCTestCase {
    func testUsesLegacyTitleOrderBeforeVersionZeroPointOneSixtyTwo() {
        let result = ZedTitleParser.parse("Cargo.toml — gendervibes", version: "0.161.2")

        XCTAssertEqual(result.entity, "Cargo.toml")
        XCTAssertEqual(result.project, "gendervibes")
    }

    func testUsesCurrentTitleOrderFromVersionZeroPointOneSixtyTwo() {
        let result = ZedTitleParser.parse("gendervibes — Cargo.toml", version: "0.162.0")

        XCTAssertEqual(result.entity, "Cargo.toml")
        XCTAssertEqual(result.project, "gendervibes")
    }

    func testDefaultsToCurrentTitleOrderWhenVersionIsUnavailable() {
        let result = ZedTitleParser.parse("gendervibes — Cargo.toml", version: nil)

        XCTAssertEqual(result.entity, "Cargo.toml")
        XCTAssertEqual(result.project, "gendervibes")
    }

    func testDefaultsToCurrentTitleOrderWhenVersionIsInvalid() {
        let result = ZedTitleParser.parse("gendervibes — Cargo.toml", version: "unknown")

        XCTAssertEqual(result.entity, "Cargo.toml")
        XCTAssertEqual(result.project, "gendervibes")
    }

    func testDefaultsToCurrentTitleOrderForMalformedNumericVersion() {
        for version in ["0.161.2junk", "0.161.2.3", "v0.161.2"] {
            let result = ZedTitleParser.parse("gendervibes — Cargo.toml", version: version)

            XCTAssertEqual(result.entity, "Cargo.toml")
            XCTAssertEqual(result.project, "gendervibes")
        }
    }

    func testDoesNotUseEntityAsProjectForAmbiguousTitle() {
        let result = ZedTitleParser.parse("Cargo.toml — Cargo.toml", version: "1.10.3")

        XCTAssertEqual(result.entity, "Cargo.toml")
        XCTAssertNil(result.project)
    }

    func testKeepsSingleComponentTitleAsEntityWithoutProject() {
        let result = ZedTitleParser.parse("Cargo.toml", version: "1.10.3")

        XCTAssertEqual(result.entity, "Cargo.toml")
        XCTAssertNil(result.project)
    }

    func testDoesNotReturnAProjectWithoutAnEntity() {
        let current = ZedTitleParser.parse("gendervibes — ", version: "1.10.3")
        let legacy = ZedTitleParser.parse(" — gendervibes", version: "0.161.2")

        XCTAssertNil(current.entity)
        XCTAssertNil(current.project)
        XCTAssertNil(legacy.entity)
        XCTAssertNil(legacy.project)
    }

    func testPreservesSeparatorsInsideEntity() {
        let current = ZedTitleParser.parse("gendervibes — foo — bar.swift", version: "1.10.3")
        let legacy = ZedTitleParser.parse("foo — bar.swift — gendervibes", version: "0.161.2")

        XCTAssertEqual(current.entity, "foo — bar.swift")
        XCTAssertEqual(current.project, "gendervibes")
        XCTAssertEqual(legacy.entity, "foo — bar.swift")
        XCTAssertEqual(legacy.project, "gendervibes")
    }
}
