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

    func testGitHubReleaseDecodingPrefersDMGAsset() throws {
        let data = Data(
            """
            {
              "tag_name": "v0.14.0",
              "html_url": "https://github.com/AXing499/HaoPaste/releases/tag/v0.14.0",
              "body": "GitHub release notes",
              "draft": false,
              "prerelease": false,
              "assets": [
                {
                  "name": "HaoPaste-0.14.0.dmg",
                  "browser_download_url": "https://github.com/AXing499/HaoPaste/releases/download/v0.14.0/HaoPaste-0.14.0.dmg"
                }
              ]
            }
            """.utf8
        )
        let manifest = try UpdateChecker.manifest(from: data)
        XCTAssertEqual(manifest.version, "v0.14.0")
        XCTAssertEqual(
            manifest.downloadURL.lastPathComponent,
            "HaoPaste-0.14.0.dmg"
        )
        XCTAssertEqual(manifest.notes, "GitHub release notes")
    }

    func testGitHubReleaseWithoutDMGAssetsFallsBackToReleasePage() throws {
        let data = Data(
            """
            {
              "tag_name": "v0.14.1",
              "html_url": "https://github.com/AXing499/HaoPaste/releases/tag/v0.14.1",
              "draft": false,
              "prerelease": false,
              "assets": []
            }
            """.utf8
        )
        let manifest = try UpdateChecker.manifest(from: data)
        XCTAssertEqual(
            manifest.downloadURL.absoluteString,
            "https://github.com/AXing499/HaoPaste/releases/tag/v0.14.1"
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
