//
//  ClipboardShelfTests.swift
//  HaoPasteTests
//

import AppKit
import XCTest
@testable import HaoPaste

@MainActor
final class ClipboardShelfTests: XCTestCase {
    func testShelfFilters() {
        let text = TestFixtures.makeTextItem("hello", type: .text)
        let code = TestFixtures.makeTextItem("let value = 1", type: .code)
        let url = TestFixtures.makeTextItem("https://example.com", type: .url)
        let color = TestFixtures.makeTextItem("#FF8A5B", type: .colorHex)
        let image = ClipboardItem(
            type: .image,
            content: "image.png",
            plainText: "图片",
            contentHash: "image"
        )
        let file = ClipboardItem(
            type: .file,
            content: "/tmp/note.txt",
            plainText: "/tmp/note.txt",
            contentHash: "file",
            filePaths: ["/tmp/note.txt"]
        )

        XCTAssertTrue(ClipboardShelfFilter.all.matches(text))
        XCTAssertTrue(ClipboardShelfFilter.all.matches(image))
        XCTAssertTrue(ClipboardShelfFilter.all.matches(file))

        XCTAssertTrue(ClipboardShelfFilter.text.matches(text))
        XCTAssertTrue(ClipboardShelfFilter.text.matches(code))
        XCTAssertTrue(ClipboardShelfFilter.text.matches(url))
        XCTAssertTrue(ClipboardShelfFilter.text.matches(color))
        XCTAssertFalse(ClipboardShelfFilter.text.matches(image))
        XCTAssertFalse(ClipboardShelfFilter.text.matches(file))

        XCTAssertTrue(ClipboardShelfFilter.image.matches(image))
        XCTAssertFalse(ClipboardShelfFilter.image.matches(text))
    }

    func testShelfCapacityAndCardWidth() {
        XCTAssertEqual(
            ClipboardShelfLayout.capacity(width: 1_440, limit: 8),
            8
        )
        XCTAssertEqual(
            ClipboardShelfLayout.capacity(width: 640, limit: 8),
            4
        )
        XCTAssertGreaterThanOrEqual(
            ClipboardShelfLayout.cardWidth(width: 1_440, count: 8),
            ClipboardShelfLayout.minCardWidth
        )
        XCTAssertLessThanOrEqual(
            ClipboardShelfLayout.cardWidth(width: 1_440, count: 8),
            ClipboardShelfLayout.maxCardWidth
        )
    }

    func testShelfRopeAndCentering() {
        let width: CGFloat = 1_440
        let cardWidth = ClipboardShelfLayout.cardWidth(
            width: width,
            count: 5
        )
        let first = ClipboardShelfLayout.centerX(
            index: 0,
            count: 5,
            width: width,
            cardWidth: cardWidth
        )
        let last = ClipboardShelfLayout.centerX(
            index: 4,
            count: 5,
            width: width,
            cardWidth: cardWidth
        )

        XCTAssertEqual(first + last, width, accuracy: 0.01)
        XCTAssertGreaterThan(
            ClipboardShelfLayout.ropeY(x: width / 2, width: width),
            ClipboardShelfLayout.ropeY(x: 0, width: width)
        )
    }

    func testRevealBandIsMiddleThirdOfMenuBar() throws {
        let screen = try XCTUnwrap(NSScreen.main ?? NSScreen.screens.first)
        let menuBar = ClipboardShelfLayout.menuBarBand(of: screen)
        let reveal = ClipboardShelfLayout.revealBand(of: screen)

        XCTAssertEqual(reveal.midX, screen.frame.midX, accuracy: 0.5)
        XCTAssertEqual(reveal.width, screen.frame.width / 3, accuracy: 1)
        XCTAssertEqual(reveal.minY, menuBar.minY)
        XCTAssertEqual(reveal.height, menuBar.height)
        XCTAssertGreaterThan(reveal.minX, menuBar.minX)
        XCTAssertLessThan(reveal.maxX, menuBar.maxX)
    }

    func testShelfHitTestIncludesSmallInset() {
        let card = CGRect(x: 100, y: 20, width: 150, height: 140)

        XCTAssertTrue(
            ClipboardShelfLayout.hitTest(
                CGPoint(x: 175, y: 90),
                in: [card]
            )
        )
        XCTAssertTrue(
            ClipboardShelfLayout.hitTest(
                CGPoint(x: 97, y: 90),
                in: [card]
            )
        )
        XCTAssertFalse(
            ClipboardShelfLayout.hitTest(
                CGPoint(x: 90, y: 90),
                in: [card]
            )
        )
        XCTAssertFalse(
            ClipboardShelfLayout.hitTest(
                CGPoint(x: 175, y: 170),
                in: [card]
            )
        )
    }

    func testShelfItemLimitValidation() throws {
        let suite = "HaoPasteTests-Shelf-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = AppSettings(defaults: defaults)
        XCTAssertTrue(settings.shelfEnabled)
        XCTAssertEqual(settings.shelfItemLimit, 8)

        settings.shelfItemLimit = 10
        settings.shelfEnabled = false

        let reloaded = AppSettings(defaults: defaults)
        XCTAssertEqual(reloaded.shelfItemLimit, 10)
        XCTAssertFalse(reloaded.shelfEnabled)

        reloaded.shelfItemLimit = 9
        XCTAssertEqual(reloaded.shelfItemLimit, 8)
    }
}
