//
//  QuickTranslationTests.swift
//  HaoPasteTests
//

import AppKit
import XCTest
@testable import HaoPaste

@MainActor
final class QuickTranslationTests: XCTestCase {
    func testAutoTranslationPolicy() {
        let english = TestFixtures.makeTextItem("Hello world")
        let chinese = TestFixtures.makeTextItem("你好，世界。今天天气很好。")
        let image = ClipboardItem(
            type: .image,
            content: "image.png",
            plainText: "图片",
            contentHash: "image"
        )

        XCTAssertTrue(
            AutoTranslationPolicy.shouldTranslate(
                item: english,
                targetLanguageID: "zh-Hans",
                lastSignature: nil,
                enabled: true
            )
        )

        let signature = AutoTranslationPolicy.signature(for: english)
        XCTAssertFalse(
            AutoTranslationPolicy.shouldTranslate(
                item: english,
                targetLanguageID: "zh-Hans",
                lastSignature: signature,
                enabled: true
            )
        )

        XCTAssertFalse(
            AutoTranslationPolicy.shouldTranslate(
                item: english,
                targetLanguageID: "en",
                lastSignature: nil,
                enabled: true
            )
        )

        XCTAssertFalse(
            AutoTranslationPolicy.shouldTranslate(
                item: chinese,
                targetLanguageID: "zh-Hans",
                lastSignature: nil,
                enabled: true
            )
        )

        XCTAssertFalse(
            AutoTranslationPolicy.shouldTranslate(
                item: english,
                targetLanguageID: "zh-Hans",
                lastSignature: nil,
                enabled: false
            )
        )

        XCTAssertFalse(
            AutoTranslationPolicy.shouldTranslate(
                item: image,
                targetLanguageID: "zh-Hans",
                lastSignature: nil,
                enabled: true
            )
        )
    }

    func testAutoTranslationLatestItemIgnoresPinOrder() {
        let pinnedOld = TestFixtures.makeTextItem(
            "old pinned item",
            isPinned: true,
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let newest = TestFixtures.makeTextItem(
            "newest item",
            createdAt: Date(timeIntervalSince1970: 200)
        )

        XCTAssertEqual(
            AutoTranslationPolicy.latestItem(in: [pinnedOld, newest])?.id,
            newest.id
        )
    }

    func testClipboardTranslationReaderTrimsText() {
        let pasteboard = TestFixtures.makeCustomPasteboard()
        pasteboard.clearContents()
        pasteboard.setString("  Hello world \n", forType: .string)

        XCTAssertEqual(
            ClipboardTranslationReader.text(from: pasteboard),
            "Hello world"
        )

        pasteboard.clearContents()
        pasteboard.setString("   \n", forType: .string)
        XCTAssertNil(ClipboardTranslationReader.text(from: pasteboard))
    }
}
