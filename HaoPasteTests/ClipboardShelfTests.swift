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

        XCTAssertTrue(text.isTextLike)
        XCTAssertTrue(code.isTextLike)
        XCTAssertTrue(url.isTextLike)
        XCTAssertTrue(color.isTextLike)
        XCTAssertFalse(image.isTextLike)
        XCTAssertFalse(file.isTextLike)
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
        let rack = ClipboardShelfLayout.rackSpan(
            width: width,
            count: 5,
            cardWidth: cardWidth
        )

        XCTAssertEqual(first + last, width, accuracy: 0.01)
        XCTAssertGreaterThan(rack.lowerBound, ClipboardShelfLayout.rackInset - 0.01)
        XCTAssertLessThan(rack.upperBound, width)
        XCTAssertGreaterThan(
            ClipboardShelfLayout.ropeY(
                x: width / 2,
                rackStart: rack.lowerBound,
                rackEnd: rack.upperBound
            ),
            ClipboardShelfLayout.ropeY(
                x: rack.lowerBound,
                rackStart: rack.lowerBound,
                rackEnd: rack.upperBound
            )
        )
        XCTAssertEqual(
            ClipboardShelfLayout.ropeY(
                x: rack.lowerBound,
                rackStart: rack.lowerBound,
                rackEnd: rack.upperBound
            ),
            ClipboardShelfLayout.lineTop,
            accuracy: 0.01
        )
    }

    func testRackSpanTracksVisibleCards() {
        let width: CGFloat = 1_440
        let cardWidth = ClipboardShelfLayout.cardWidth(
            width: width,
            count: 8
        )
        let full = ClipboardShelfLayout.rackSpan(
            width: width,
            count: 8,
            cardWidth: cardWidth
        )
        let short = ClipboardShelfLayout.rackSpan(
            width: width,
            count: 2,
            cardWidth: cardWidth
        )
        let empty = ClipboardShelfLayout.rackSpan(
            width: width,
            count: 0,
            cardWidth: cardWidth
        )

        XCTAssertGreaterThan(full.upperBound - full.lowerBound, short.upperBound - short.lowerBound)
        XCTAssertGreaterThan(short.upperBound - short.lowerBound, empty.upperBound - empty.lowerBound)
        XCTAssertEqual(full.lowerBound + full.upperBound, width, accuracy: 0.5)
        XCTAssertEqual(short.lowerBound + short.upperBound, width, accuracy: 0.5)
        XCTAssertEqual(empty.lowerBound + empty.upperBound, width, accuracy: 0.5)
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

    func testSideShelfGeometry() {
        XCTAssertEqual(
            ClipboardShelfLayout.sideCapacity(height: 1_050, limit: 8),
            6
        )
        XCTAssertEqual(
            ClipboardShelfLayout.sideCapacity(height: 1_440, limit: 8),
            8
        )
        XCTAssertEqual(
            ClipboardShelfLayout.sideCardWidth(panelWidth: 232),
            156
        )
        XCTAssertEqual(
            ClipboardShelfLayout.sideCardTop(index: 0),
            ClipboardShelfLayout.sideTopPadding
        )
        XCTAssertEqual(
            ClipboardShelfLayout.sideCardTop(index: 2),
            ClipboardShelfLayout.sideTopPadding
                + 2 * (ClipboardShelfLayout.cardHeight
                    + ClipboardShelfLayout.sideSpacing)
        )

        let rack = ClipboardShelfLayout.sideRackRange(
            height: 1_050,
            count: 6
        )
        XCTAssertGreaterThan(rack.lowerBound, 0)
        XCTAssertLessThan(rack.upperBound, 1_050)
        XCTAssertLessThan(rack.upperBound, 1_050 - ClipboardShelfLayout.filterBarHeight)
    }

    func testSideRevealBandAndPanelFrames() throws {
        let screen = try XCTUnwrap(NSScreen.main ?? NSScreen.screens.first)
        let visible = screen.visibleFrame

        let leftReveal = ClipboardShelfLayout.revealBand(
            of: screen,
            edge: .left
        )
        XCTAssertEqual(leftReveal.minX, visible.minX, accuracy: 0.5)
        XCTAssertEqual(leftReveal.midY, visible.midY, accuracy: 0.5)
        XCTAssertEqual(
            leftReveal.height,
            visible.height / 3,
            accuracy: 1
        )
        XCTAssertGreaterThanOrEqual(leftReveal.width, 8)
        XCTAssertLessThanOrEqual(leftReveal.width, 12)

        let rightReveal = ClipboardShelfLayout.revealBand(
            of: screen,
            edge: .right
        )
        XCTAssertEqual(rightReveal.maxX, visible.maxX, accuracy: 0.5)

        let leftFrame = ClipboardShelfLayout.panelFrame(
            on: screen,
            edge: .left
        )
        XCTAssertEqual(leftFrame.minX, visible.minX, accuracy: 0.5)
        XCTAssertEqual(
            leftFrame.width,
            ClipboardShelfLayout.sidePanelWidth,
            accuracy: 0.5
        )
        XCTAssertEqual(leftFrame.height, visible.height, accuracy: 0.5)

        let rightFrame = ClipboardShelfLayout.panelFrame(
            on: screen,
            edge: .right
        )
        XCTAssertEqual(rightFrame.maxX, visible.maxX, accuracy: 0.5)

        XCTAssertEqual(
            ClipboardShelfLayout.hoverOffset(for: .left).width,
            8
        )
        XCTAssertEqual(
            ClipboardShelfLayout.hoverOffset(for: .right).width,
            -8
        )
        XCTAssertEqual(
            ClipboardShelfLayout.hoverOffset(for: .top).height,
            -5
        )
    }

    func testShelfHitTargetReturnsCardIdentity() {
        let id = UUID()
        let card = ShelfHitTarget(
            kind: .card(id),
            rect: CGRect(x: 100, y: 20, width: 150, height: 140)
        )
        let filter = ShelfHitTarget(
            kind: .filterBar,
            rect: CGRect(x: 500, y: 190, width: 180, height: 28)
        )

        let target = ClipboardShelfLayout.hitTarget(
            at: CGPoint(x: 175, y: 90),
            in: [filter, card]
        )
        XCTAssertEqual(target?.kind, .card(id))
        XCTAssertNil(
            ClipboardShelfLayout.hitTarget(
                at: CGPoint(x: 400, y: 90),
                in: [filter, card]
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
