//
//  MultiSelectionTests.swift
//  HaoPasteTests
//

import AppKit
import XCTest
@testable import HaoPaste

@MainActor
final class MultiSelectionTests: XCTestCase {
    // MARK: - Selection state

    func testCommandSelectionTogglesAndClears() {
        let state = PanelViewState()
        let items = [
            TestFixtures.makeTextItem("A"),
            TestFixtures.makeTextItem("B"),
            TestFixtures.makeTextItem("C")
        ]
        state.selectedID = items[0].id

        state.toggleMultiSelection(items[1], in: items)
        XCTAssertEqual(state.selectedIDs, [items[0].id, items[1].id])
        XCTAssertEqual(state.selectedID, items[1].id)
        XCTAssertTrue(state.isMultiSelecting)

        state.toggleMultiSelection(items[2], in: items)
        XCTAssertEqual(
            state.selectedIDs,
            [items[0].id, items[1].id, items[2].id]
        )

        state.toggleMultiSelection(items[1], in: items)
        XCTAssertEqual(state.selectedIDs, [items[0].id, items[2].id])
        XCTAssertEqual(state.selectedID, items[2].id)

        state.toggleMultiSelection(items[2], in: items)
        XCTAssertTrue(state.selectedIDs.isEmpty)
        XCTAssertFalse(state.isMultiSelecting)
        XCTAssertEqual(state.selectedID, items[0].id)
    }

    func testShiftSelectionKeepsAnchor() {
        let state = PanelViewState()
        let items = [
            TestFixtures.makeTextItem("A"),
            TestFixtures.makeTextItem("B"),
            TestFixtures.makeTextItem("C"),
            TestFixtures.makeTextItem("D")
        ]
        state.selectedID = items[1].id

        state.extendSelection(to: items[3], in: items)
        XCTAssertEqual(
            state.selectedIDs,
            [items[1].id, items[2].id, items[3].id]
        )
        XCTAssertEqual(state.selectionAnchorID, items[1].id)
        XCTAssertEqual(state.selectedID, items[3].id)

        state.extendSelection(to: items[2], in: items)
        XCTAssertEqual(state.selectedIDs, [items[1].id, items[2].id])
        XCTAssertEqual(state.selectedID, items[2].id)

        state.extendSelection(to: items[0], in: items)
        XCTAssertEqual(state.selectedIDs, [items[0].id, items[1].id])
        XCTAssertEqual(state.selectionAnchorID, items[1].id)
    }

    func testShiftArrowExtendsAndPlainArrowClears() {
        let state = PanelViewState()
        let items = [
            TestFixtures.makeTextItem("A"),
            TestFixtures.makeTextItem("B"),
            TestFixtures.makeTextItem("C")
        ]
        state.selectedID = items[1].id

        state.moveSelection(in: items, by: 1, extending: true)
        XCTAssertEqual(state.selectedIDs, [items[1].id, items[2].id])
        XCTAssertEqual(state.selectedID, items[2].id)

        state.moveSelection(in: items, by: 1, extending: false)
        XCTAssertTrue(state.selectedIDs.isEmpty)
        XCTAssertFalse(state.isMultiSelecting)
        XCTAssertEqual(state.selectedID, items[2].id)
    }

    func testSelectAllAndPruneDeletedItems() {
        let state = PanelViewState()
        let items = [
            TestFixtures.makeTextItem("A"),
            TestFixtures.makeTextItem("B"),
            TestFixtures.makeTextItem("C")
        ]
        state.selectedID = items[1].id

        state.selectAll(in: items)
        XCTAssertEqual(state.selectedIDs.count, 3)
        XCTAssertTrue(state.isMultiSelecting)
        XCTAssertEqual(state.selectedID, items[1].id)

        state.ensureSelection(in: [items[0], items[1]])
        XCTAssertEqual(state.selectedIDs, [items[0].id, items[1].id])

        state.ensureSelection(in: [items[0]])
        XCTAssertTrue(state.selectedIDs.isEmpty)
        XCTAssertFalse(state.isMultiSelecting)
        XCTAssertEqual(state.selectedID, items[0].id)
    }

    // MARK: - Merged content

    func testMergedTextPreservesVisibleOrder() {
        let items = [
            TestFixtures.makeTextItem("first"),
            TestFixtures.makeTextItem("second"),
            TestFixtures.makeTextItem("third", type: .code)
        ]

        XCTAssertEqual(
            MergedContentBuilder.make(from: items),
            .text("first\nsecond\nthird")
        )
    }

    func testMergedFilesReturnsAllAvailableURLs() throws {
        let directory = try TestFixtures.temporaryDirectory()
        defer { TestFixtures.remove(directory) }

        let first = directory.appendingPathComponent("one.txt")
        let second = directory.appendingPathComponent("two.txt")
        try Data("one".utf8).write(to: first)
        try Data("two".utf8).write(to: second)

        let items = [
            makeFileItem(paths: [first.path]),
            makeFileItem(paths: [second.path])
        ]

        XCTAssertEqual(
            MergedContentBuilder.make(from: items),
            .fileURLs([first, second])
        )
    }

    func testMergedMixedTextAndFileUsesPath() throws {
        let directory = try TestFixtures.temporaryDirectory()
        defer { TestFixtures.remove(directory) }

        let file = directory.appendingPathComponent("note.txt")
        try Data("note".utf8).write(to: file)

        let items = [
            TestFixtures.makeTextItem("context"),
            makeFileItem(paths: [file.path])
        ]

        XCTAssertEqual(
            MergedContentBuilder.make(from: items),
            .text("context\n\(file.path)")
        )
    }

    func testMergedFileURLsAreDeduplicated() throws {
        let directory = try TestFixtures.temporaryDirectory()
        defer { TestFixtures.remove(directory) }

        let file = directory.appendingPathComponent("same.txt")
        try Data("same".utf8).write(to: file)

        let items = [
            makeFileItem(paths: [file.path]),
            makeFileItem(paths: [file.path])
        ]

        XCTAssertEqual(
            MergedContentBuilder.make(from: items),
            .fileURLs([file])
        )
    }

    func testMergedImagesAreUnsupported() {
        let image = ClipboardItem(
            type: .image,
            content: "image.png",
            plainText: "图片",
            contentHash: ContentHasher.imageData(Data("image".utf8))
        )

        XCTAssertEqual(
            MergedContentBuilder.make(from: [image]),
            .unsupported
        )
    }

    // MARK: - Manager copy

    func testManagerCopiesMergedText() throws {
        let directory = try TestFixtures.temporaryDirectory()
        defer { TestFixtures.remove(directory) }

        let pasteboard = TestFixtures.makeCustomPasteboard()
        let manager = ClipboardManager(
            store: ClipboardStore(baseURL: directory),
            monitor: ClipboardMonitor(pasteboard: pasteboard)
        )
        manager.start()
        defer { manager.shutdown() }

        let items = [
            TestFixtures.makeTextItem("alpha"),
            TestFixtures.makeTextItem("beta")
        ]

        XCTAssertTrue(manager.copyMergedToPasteboard(items))
        XCTAssertEqual(pasteboard.string(forType: .string), "alpha\nbeta")
    }

    func testManagerCopiesMergedFilesAsURLs() throws {
        let directory = try TestFixtures.temporaryDirectory()
        defer { TestFixtures.remove(directory) }

        let first = directory.appendingPathComponent("first.txt")
        let second = directory.appendingPathComponent("second.txt")
        try Data("first".utf8).write(to: first)
        try Data("second".utf8).write(to: second)

        let pasteboard = TestFixtures.makeCustomPasteboard()
        let manager = ClipboardManager(
            store: ClipboardStore(baseURL: directory),
            monitor: ClipboardMonitor(pasteboard: pasteboard)
        )
        manager.start()
        defer { manager.shutdown() }

        let items = [
            makeFileItem(paths: [first.path]),
            makeFileItem(paths: [second.path])
        ]

        XCTAssertTrue(manager.copyMergedToPasteboard(items))
        let urls = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: nil
        ) as? [URL]
        XCTAssertEqual(urls?.map(\.path), [first.path, second.path])
    }

    // MARK: - Helpers

    private func makeFileItem(paths: [String]) -> ClipboardItem {
        ClipboardItem(
            type: .file,
            content: paths.joined(separator: "\n"),
            plainText: paths.joined(separator: "\n"),
            contentHash: ContentHasher.files(paths),
            filePaths: paths
        )
    }
}
