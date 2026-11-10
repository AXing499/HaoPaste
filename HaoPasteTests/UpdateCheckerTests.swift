//
//  UpdateCheckerTests.swift
//  HaoPasteTests
//

import XCTest
@testable import HaoPaste

final class UpdateCheckerTests: XCTestCase {
    func testVersionComparison() {
        XCTAssertTrue(
            UpdateChecker.isNewer(version: "0.14.0", than: "0.13.16")
        )
        XCTAssertTrue(
            UpdateChecker.isNewer(version: "1.0.1", than: "1.0")
        )
        XCTAssertFalse(
            UpdateChecker.isNewer(version: "0.13.16", than: "0.13.16")
        )
        XCTAssertFalse(
            UpdateChecker.isNewer(version: "v0.13.16", than: "0.13.16")
        )
        XCTAssertFalse(
            UpdateChecker.isNewer(version: "0.9", than: "0.10")
        )
    }

    func testManifestDecoding() throws {
        let data = Data(
            """
            {
              "version": "0.14.0",
              "downloadURL": "https://example.com/HaoPaste-0.14.0.dmg",
              "notes": "最近删除与片段入口"
            }
            """.utf8
        )
        let manifest = try JSONDecoder().decode(
            UpdateManifest.self,
            from: data
        )
        XCTAssertEqual(manifest.version, "0.14.0")
        XCTAssertEqual(
            manifest.downloadURL.absoluteString,
            "https://example.com/HaoPaste-0.14.0.dmg"
        )
        XCTAssertEqual(manifest.notes, "最近删除与片段入口")
    }
}
