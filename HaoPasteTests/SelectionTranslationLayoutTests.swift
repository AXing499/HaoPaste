//
//  SelectionTranslationLayoutTests.swift
//  HaoPasteTests
//

import AppKit
import XCTest
@testable import HaoPaste

final class SelectionTranslationLayoutTests: XCTestCase {
    private let visibleFrame = NSRect(
        x: 0,
        y: 0,
        width: 1_440,
        height: 900
    )

    func testCardPrefersBelowAndRightOfSelection() {
        let frame = SelectionTranslationLayout.cardFrame(
            anchor: NSPoint(x: 800, y: 500),
            size: NSSize(width: 400, height: 340),
            visibleFrame: visibleFrame
        )

        XCTAssertGreaterThan(frame.minX, 800)
        XCTAssertLessThan(frame.maxY, 500)
        XCTAssertTrue(visibleFrame.contains(frame))
    }

    func testCardFlipsAboveWhenSelectionIsNearBottom() {
        let frame = SelectionTranslationLayout.cardFrame(
            anchor: NSPoint(x: 800, y: 20),
            size: NSSize(width: 400, height: 340),
            visibleFrame: visibleFrame
        )

        XCTAssertGreaterThan(frame.minY, 20)
        XCTAssertTrue(visibleFrame.contains(frame))
    }

    func testCardFlipsLeftWhenSelectionIsNearRightEdge() {
        let frame = SelectionTranslationLayout.cardFrame(
            anchor: NSPoint(x: 1_430, y: 500),
            size: NSSize(width: 400, height: 340),
            visibleFrame: visibleFrame
        )

        XCTAssertLessThan(frame.maxX, 1_430)
        XCTAssertTrue(visibleFrame.contains(frame))
    }

    func testIconStaysInsideVisibleFrame() {
        let frame = SelectionTranslationLayout.iconFrame(
            anchor: NSPoint(x: 1_435, y: 5),
            size: 32,
            visibleFrame: visibleFrame
        )

        XCTAssertTrue(visibleFrame.contains(frame))
        XCTAssertEqual(frame.size, NSSize(width: 32, height: 32))
    }

    func testIconPrefersAboveSelection() {
        let frame = SelectionTranslationLayout.iconFrame(
            anchor: NSPoint(x: 800, y: 500),
            size: 32,
            visibleFrame: visibleFrame
        )

        XCTAssertGreaterThan(frame.minY, 500)
        XCTAssertEqual(frame.midX, 800, accuracy: 1)
        XCTAssertTrue(visibleFrame.contains(frame))
    }

    func testIconFlipsBelowNearTopEdge() {
        let frame = SelectionTranslationLayout.iconFrame(
            anchor: NSPoint(x: 800, y: 890),
            size: 32,
            visibleFrame: visibleFrame
        )

        XCTAssertLessThan(frame.maxY, 890)
        XCTAssertTrue(visibleFrame.contains(frame))
    }
}
