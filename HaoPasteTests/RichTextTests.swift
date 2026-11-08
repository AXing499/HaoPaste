//
//  RichTextTests.swift
//  HaoPasteTests
//

import AppKit
import XCTest
@testable import HaoPaste

@MainActor
final class RichTextTests: XCTestCase {
    func testRichTextStoreAndPasteboardCopy() throws {
        let directory = try TestFixtures.temporaryDirectory()
        defer { TestFixtures.remove(directory) }

        let store = ClipboardStore(baseURL: directory)
        let id = UUID()
        let payload = RichTextPayload(
            rtfData: Data(#"{\rtf1\ansi Hello}"#.utf8),
            htmlData: Data("<b>Hello</b>".utf8)
        )
        let fileName = try store.saveRichText(payload, id: id)
        let text = "Hello"
        let item = ClipboardItem(
            id: id,
            type: .text,
            content: text,
            plainText: text,
            contentHash: ContentHasher.richText(
                text,
                type: .text,
                rtf: payload.rtfData,
                html: payload.htmlData
            ),
            richTextFileName: fileName
        )

        XCTAssertTrue(item.hasRichText)
        XCTAssertEqual(store.loadRichText(for: item), payload)

        let pasteboard = TestFixtures.makeCustomPasteboard()
        let manager = ClipboardManager(
            store: store,
            monitor: ClipboardMonitor(pasteboard: pasteboard)
        )

        XCTAssertTrue(manager.copyToPasteboard(item))
        XCTAssertEqual(pasteboard.string(forType: .string), text)
        XCTAssertEqual(pasteboard.data(forType: .rtf), payload.rtfData)
        XCTAssertEqual(pasteboard.data(forType: .html), payload.htmlData)
    }

    func testMissingRichTextFileDegradesToPlainTextOnLoad() throws {
        let directory = try TestFixtures.temporaryDirectory()
        defer { TestFixtures.remove(directory) }

        let store = ClipboardStore(baseURL: directory)
        let item = ClipboardItem(
            type: .text,
            content: "Hello",
            plainText: "Hello",
            contentHash: ContentHasher.text("Hello", type: .text),
            richTextFileName: "missing.json"
        )
        store.saveNow([item])

        let reloaded = ClipboardStore(baseURL: directory).loadItems()
        XCTAssertEqual(reloaded.count, 1)
        XCTAssertFalse(reloaded[0].hasRichText)
        XCTAssertNil(reloaded[0].richTextFileName)
    }
}
