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

    func testShelfCardWidth() {
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
            ClipboardShelfLayout.sideCardWidth(panelWidth: 232),
            156
        )
        let heights = Array(
            repeating: ClipboardShelfLayout.cardHeight,
            count: 3
        )
        let tops = ClipboardShelfLayout.sideCardTops(
            cardHeights: heights
        )
        XCTAssertEqual(tops[0], ClipboardShelfLayout.sideTopPadding)
        XCTAssertEqual(
            tops[2],
            ClipboardShelfLayout.sideTopPadding
                + 2 * (ClipboardShelfLayout.cardHeight
                    + ClipboardShelfLayout.sideSpacing)
        )

        let rack = ClipboardShelfLayout.sideRackRange(
            height: 1_050,
            contentBottom: tops[2] + heights[2],
            scrollable: false
        )
        XCTAssertGreaterThan(rack.lowerBound, 0)
        XCTAssertLessThan(rack.upperBound, 1_050)
        XCTAssertLessThan(rack.upperBound, 1_050 - ClipboardShelfLayout.filterBarHeight)
    }

    func testDynamicCardHeights() {
        let shortText = TestFixtures.makeTextItem(
            "短文本",
            type: .text
        )
        let longText = TestFixtures.makeTextItem(
            String(repeating: "长文本内容", count: 80),
            type: .text
        )
        let landscape = ClipboardItem(
            type: .image,
            content: "landscape.png",
            plainText: "图片",
            contentHash: "landscape",
            imageDimensions: ImageDimensions(width: 1_600, height: 900)
        )
        let portrait = ClipboardItem(
            type: .image,
            content: "portrait.png",
            plainText: "图片",
            contentHash: "portrait",
            imageDimensions: ImageDimensions(width: 900, height: 1_600)
        )

        let shortHeight = ClipboardShelfLayout.cardHeight(
            for: shortText,
            cardWidth: 156,
            edge: .top
        )
        let longTopHeight = ClipboardShelfLayout.cardHeight(
            for: longText,
            cardWidth: 156,
            edge: .top
        )
        let longSideHeight = ClipboardShelfLayout.cardHeight(
            for: longText,
            cardWidth: 156,
            edge: .left
        )
        let landscapeHeight = ClipboardShelfLayout.cardHeight(
            for: landscape,
            cardWidth: 156,
            edge: .top
        )
        let portraitTopHeight = ClipboardShelfLayout.cardHeight(
            for: portrait,
            cardWidth: 156,
            edge: .top
        )
        let portraitSideHeight = ClipboardShelfLayout.cardHeight(
            for: portrait,
            cardWidth: 156,
            edge: .left
        )

        XCTAssertEqual(
            shortHeight,
            ClipboardShelfLayout.minCardHeight,
            accuracy: 0.5
        )
        XCTAssertGreaterThan(longTopHeight, shortHeight)
        XCTAssertLessThanOrEqual(
            longTopHeight,
            ClipboardShelfLayout.maxTopCardHeight
        )
        XCTAssertGreaterThan(longSideHeight, longTopHeight)
        XCTAssertGreaterThan(portraitTopHeight, landscapeHeight)
        XCTAssertEqual(
            portraitTopHeight,
            ClipboardShelfLayout.maxTopCardHeight,
            accuracy: 0.5
        )
        XCTAssertEqual(
            portraitSideHeight,
            ClipboardShelfLayout.maxSideCardHeight,
            accuracy: 0.5
        )
        XCTAssertEqual(
            ClipboardShelfLayout.textLineLimit(
                forCardHeight: ClipboardShelfLayout.maxTopCardHeight,
                isFile: false
            ),
            4
        )
        XCTAssertEqual(
            ClipboardShelfLayout.textLineLimit(
                forCardHeight: ClipboardShelfLayout.maxSideCardHeight,
                isFile: false
            ),
            6
        )
    }

    func testShelfScrollMetrics() {
        let heights = Array(
            repeating: ClipboardShelfLayout.cardHeight,
            count: 8
        )
        XCTAssertEqual(
            ClipboardShelfLayout.sideMaxScrollOffset(
                height: 1_050,
                cardHeights: heights
            ),
            276,
            accuracy: 0.5
        )
        XCTAssertEqual(
            ClipboardShelfLayout.sideMaxScrollOffset(
                height: 1_050,
                cardHeights: Array(
                    repeating: ClipboardShelfLayout.cardHeight,
                    count: 6
                )
            ),
            0,
            accuracy: 0.5
        )
        XCTAssertEqual(
            ClipboardShelfLayout.topMaxScrollOffset(
                width: 1_440,
                count: 11,
                cardWidth: 118
            ),
            78,
            accuracy: 0.5
        )
        XCTAssertEqual(
            ClipboardShelfLayout.topMaxScrollOffset(
                width: 1_920,
                count: 8,
                cardWidth: 156
            ),
            0,
            accuracy: 0.5
        )

        let sideRack = ClipboardShelfLayout.sideRackRange(
            height: 1_050,
            contentBottom: 0,
            scrollable: true
        )
        XCTAssertEqual(
            sideRack.lowerBound,
            ClipboardShelfLayout.sideRackInset,
            accuracy: 0.5
        )
        XCTAssertEqual(
            sideRack.upperBound,
            ClipboardShelfLayout.sideVisibleBottom(height: 1_050)
                - ClipboardShelfLayout.sideRackInset,
            accuracy: 0.5
        )

        let topRack = ClipboardShelfLayout.topRackSpan(
            width: 1_440,
            count: 11,
            cardWidth: 118,
            scrollable: true
        )
        XCTAssertEqual(
            topRack.lowerBound,
            ClipboardShelfLayout.rackInset,
            accuracy: 0.5
        )
        XCTAssertEqual(topRack.upperBound, 1_424, accuracy: 0.5)

        let sideRange = ClipboardShelfLayout.sideVisibleRange(
            cardTops: ClipboardShelfLayout.sideCardTops(
                cardHeights: heights
            ),
            cardHeights: heights,
            offset: 276,
            height: 1_050,
            buffer: 0
        )
        XCTAssertFalse(sideRange.isEmpty)
        XCTAssertLessThanOrEqual(sideRange.upperBound, 8)

        let topRange = ClipboardShelfLayout.topVisibleRange(
            width: 1_440,
            count: 11,
            cardWidth: 118,
            offset: 78,
            scrollable: true,
            buffer: 0
        )
        XCTAssertFalse(topRange.isEmpty)
        XCTAssertEqual(topRange.lowerBound, 0)
        XCTAssertLessThanOrEqual(topRange.upperBound, 11)
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
