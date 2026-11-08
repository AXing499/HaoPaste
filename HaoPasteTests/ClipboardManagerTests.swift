//
//  ClipboardManagerTests.swift
//  HaoPasteTests
//

import XCTest
@testable import HaoPaste

@MainActor
final class ClipboardManagerTests: XCTestCase {
    func testHistoryLimitTrimKeepsPinnedItems() throws {
        let directory = try TestFixtures.temporaryDirectory()
        defer { TestFixtures.remove(directory) }

        let store = ClipboardStore(baseURL: directory)
        let now = Date()
        var seeded: [ClipboardItem] = []

        for index in 0..<120 {
            seeded.append(
                TestFixtures.makeTextItem(
                    "unpinned-\(index)",
                    createdAt: now.addingTimeInterval(-Double(index))
                )
            )
        }
        seeded.append(
            TestFixtures.makeTextItem(
                "pinned-old-1",
                isPinned: true,
                createdAt: now.addingTimeInterval(-10_000)
            )
        )
        seeded.append(
            TestFixtures.makeTextItem(
                "pinned-old-2",
                isPinned: true,
                createdAt: now.addingTimeInterval(-20_000)
            )
        )
        store.saveNow(seeded)

        let manager = ClipboardManager(
            store: store,
            monitor: ClipboardMonitor(pasteboard: TestFixtures.makeCustomPasteboard())
        )
        manager.start()
        defer { manager.shutdown() }

        XCTAssertEqual(manager.items.count, 122)

        manager.updateMaxUnpinnedItems(100)

        XCTAssertEqual(manager.items.count, 102)
        XCTAssertEqual(manager.pinnedCount, 2)
        XCTAssertEqual(manager.unpinnedCount, 100)
        XCTAssertTrue(manager.items.contains { $0.plainText == "unpinned-0" })
        XCTAssertFalse(manager.items.contains { $0.plainText == "unpinned-119" })
        XCTAssertTrue(manager.items.contains { $0.plainText == "pinned-old-1" })
        XCTAssertTrue(manager.items.contains { $0.plainText == "pinned-old-2" })
    }

    func testClearUnpinnedAndClearAll() throws {
        let directory = try TestFixtures.temporaryDirectory()
        defer { TestFixtures.remove(directory) }

        let store = ClipboardStore(baseURL: directory)
        let now = Date()
        let items = [
            TestFixtures.makeTextItem("text", createdAt: now),
            TestFixtures.makeTextItem("pinned", isPinned: true, createdAt: now.addingTimeInterval(-1))
        ]
        store.saveNow(items)

        let manager = ClipboardManager(
            store: store,
            monitor: ClipboardMonitor(pasteboard: TestFixtures.makeCustomPasteboard())
        )
        manager.start()
        defer { manager.shutdown() }

        manager.clearUnpinnedItems()
        XCTAssertEqual(manager.items.count, 1)
        XCTAssertEqual(manager.pinnedCount, 1)
        XCTAssertEqual(manager.items.first?.plainText, "pinned")

        manager.clearAllItems()
        XCTAssertTrue(manager.items.isEmpty)
    }

    func testUpdateMaxHistoryLimitDoesNotGrowHistory() throws {
        let directory = try TestFixtures.temporaryDirectory()
        defer { TestFixtures.remove(directory) }

        let store = ClipboardStore(baseURL: directory)
        let items = [
            TestFixtures.makeTextItem("one"),
            TestFixtures.makeTextItem("two")
        ]
        store.saveNow(items)

        let manager = ClipboardManager(
            store: store,
            monitor: ClipboardMonitor(pasteboard: TestFixtures.makeCustomPasteboard())
        )
        manager.start()
        defer { manager.shutdown() }

        manager.updateMaxUnpinnedItems(1_000)
        XCTAssertEqual(manager.items.count, 2)
    }

    func testCopyArbitraryTextWritesPasteboard() throws {
        let directory = try TestFixtures.temporaryDirectory()
        defer { TestFixtures.remove(directory) }

        let pasteboard = TestFixtures.makeCustomPasteboard()
        let manager = ClipboardManager(
            store: ClipboardStore(baseURL: directory),
            monitor: ClipboardMonitor(pasteboard: pasteboard)
        )

        XCTAssertTrue(manager.copyTextToPasteboard("rgb(255, 138, 91)"))
        XCTAssertEqual(
            pasteboard.string(forType: .string),
            "rgb(255, 138, 91)"
        )
    }
}
