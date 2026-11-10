//
//  ClipboardItemTests.swift
//  HaoPasteTests
//

import XCTest
@testable import HaoPaste

final class ClipboardItemTests: XCTestCase {
    func testJSONFormatBadge() {
        let item = TestFixtures.makeTextItem(
            "{\"name\": \"HaoPaste\"}",
            type: .code
        )
        XCTAssertEqual(item.formatBadge, "JSON")
        XCTAssertEqual(item.displayTitle, "{\"name\": \"HaoPaste\"}")
    }

    func testCodeFormatBadge() {
        let item = TestFixtures.makeTextItem(
            "struct Panel { }",
            type: .code
        )
        XCTAssertEqual(item.formatBadge, L("代码"))
        XCTAssertEqual(item.displayTitle, "struct Panel { }")
    }

    func testDetailBadges() {
        let text = TestFixtures.makeTextItem("hello")
        XCTAssertEqual(text.detailBadge, L("%d 字符", 5))

        let image = ClipboardItem(
            type: .image,
            content: "image.png",
            plainText: "图片",
            contentHash: "hash",
            imageFileName: "image.png",
            imageDimensions: ImageDimensions(width: 1_440, height: 900)
        )
        XCTAssertEqual(image.formatBadge, L("图片"))
        XCTAssertEqual(image.detailBadge, "1440 × 900")
    }

    func testSearchMatchesContentSourceAndType() {
        let item = TestFixtures.makeTextItem(
            "Hello from HaoPaste",
            sourceApp: SourceApplication(
                bundleIdentifier: "com.apple.Safari",
                name: "Safari"
            )
        )

        XCTAssertTrue(item.matches("haopaste"))
        XCTAssertTrue(item.matches("safari"))
        XCTAssertTrue(item.matches(L("文本")))
        XCTAssertFalse(item.matches("not-found"))
    }

    func testFilterMatching() {
        let color = TestFixtures.makeTextItem("#FF8A5B", type: .colorHex)
        let link = TestFixtures.makeTextItem("https://example.com", type: .url)
        let image = ClipboardItem(
            type: .image,
            content: "image.png",
            plainText: "图片",
            contentHash: "hash"
        )

        XCTAssertTrue(ClipboardFilter.text.matches(color))
        XCTAssertFalse(ClipboardFilter.code.matches(color))
        XCTAssertTrue(ClipboardFilter.url.matches(link))
        XCTAssertTrue(ClipboardFilter.image.matches(image))
        XCTAssertTrue(ClipboardFilter.all.matches(image))
    }
}
