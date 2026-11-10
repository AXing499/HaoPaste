//
//  MultiFileDragTests.swift
//  HaoPasteTests
//

import AppKit
import XCTest
@testable import HaoPaste

@MainActor
final class MultiFileDragTests: XCTestCase {
    func testDraggingItemsIncludesEveryAvailableFile() throws {
        let directory = try TestFixtures.temporaryDirectory()
        defer { TestFixtures.remove(directory) }

        let urls = [
            directory.appendingPathComponent("first.txt"),
            directory.appendingPathComponent("second.txt")
        ]
        try Data("first".utf8).write(to: urls[0])
        try Data("second".utf8).write(to: urls[1])

        let items = MultiFileDragSourceView.draggingItems(
            for: urls,
            centeredAt: NSPoint(x: 20, y: 20)
        )

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].draggingFrame.size, NSSize(width: 32, height: 32))
        XCTAssertEqual(items[1].draggingFrame.size, NSSize(width: 32, height: 32))
    }
}
