//
//  TrashTests.swift
//  HaoPasteTests
//

import XCTest
@testable import HaoPaste

@MainActor
final class TrashTests: XCTestCase {
    func testDeleteMovesItemToTrashAndRestoreBringsItBack() throws {
        let directory = try TestFixtures.temporaryDirectory()
        defer { TestFixtures.remove(directory) }

        let store = ClipboardStore(baseURL: directory)
        let item = TestFixtures.makeTextItem("recover me")
        store.saveNow([item])

        let manager = ClipboardManager(
            store: store,
            monitor: ClipboardMonitor(
                pasteboard: TestFixtures.makeCustomPasteboard()
            )
        )
        manager.start()
        defer { manager.shutdown() }

        XCTAssertEqual(manager.items.count, 1)

        manager.delete(item)
        XCTAssertEqual(manager.items.count, 0)
        XCTAssertEqual(manager.trashedItems.count, 1)

        let trashed = try XCTUnwrap(manager.trashedItems.first)
        manager.restore(trashed)
        XCTAssertEqual(manager.items.count, 1)
        XCTAssertEqual(manager.items.first?.plainText, "recover me")
        XCTAssertEqual(manager.trashedItems.count, 0)
    }

    func testExpiredTrashIsPurgedOnStart() throws {
        let directory = try TestFixtures.temporaryDirectory()
        defer { TestFixtures.remove(directory) }

        let store = ClipboardStore(baseURL: directory)
        let old = TrashedClipboardItem(
            item: TestFixtures.makeTextItem("old"),
            deletedAt: Date().addingTimeInterval(-8 * 24 * 60 * 60)
        )
        let fresh = TrashedClipboardItem(
            item: TestFixtures.makeTextItem("fresh"),
            deletedAt: .now
        )
        store.saveTrashNow([old, fresh])

        let manager = ClipboardManager(
            store: store,
            monitor: ClipboardMonitor(
                pasteboard: TestFixtures.makeCustomPasteboard()
            )
        )
        manager.start()
        defer { manager.shutdown() }

        XCTAssertEqual(manager.trashedItems.count, 1)
        XCTAssertEqual(manager.trashedItems.first?.item.plainText, "fresh")
    }
}
