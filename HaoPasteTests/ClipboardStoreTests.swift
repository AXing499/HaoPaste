//
//  ClipboardStoreTests.swift
//  HaoPasteTests
//

import AppKit
import XCTest
@testable import HaoPaste

@MainActor
final class ClipboardStoreTests: XCTestCase {
    func testTextHistoryRoundTrip() throws {
        let directory = try TestFixtures.temporaryDirectory()
        defer { TestFixtures.remove(directory) }

        let store = ClipboardStore(baseURL: directory)
        let first = TestFixtures.makeTextItem(
            "hello",
            isPinned: true,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let second = TestFixtures.makeTextItem(
            "https://example.com",
            type: .url,
            createdAt: Date(timeIntervalSince1970: 1_700_000_100)
        )

        store.saveNow([first, second])

        let reloaded = ClipboardStore(baseURL: directory).loadItems()
        XCTAssertEqual(reloaded.count, 2)
        XCTAssertTrue(reloaded.contains { $0.content == "hello" && $0.isPinned })
        XCTAssertTrue(reloaded.contains { $0.type == .url })
    }

    func testImageAssetsAndItemRoundTrip() throws {
        let directory = try TestFixtures.temporaryDirectory()
        defer { TestFixtures.remove(directory) }

        let store = ClipboardStore(baseURL: directory)
        let id = UUID()
        let data = TestFixtures.makePNGData()
        let stored = try store.saveImage(data: data, id: id)

        XCTAssertEqual(stored.dimensions.width, 32)
        XCTAssertEqual(stored.dimensions.height, 24)
        let imageURL = directory
            .appendingPathComponent("Images", isDirectory: true)
            .appendingPathComponent(stored.fileName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: imageURL.path))

        let item = ClipboardItem(
            id: id,
            type: .image,
            content: stored.fileName,
            plainText: "图片 \(stored.dimensions.displayText)",
            isPinned: true,
            createdAt: .now,
            contentHash: ContentHasher.imageData(data),
            imageFileName: stored.fileName,
            thumbnailFileName: stored.thumbnailFileName,
            imageDimensions: stored.dimensions
        )

        store.saveNow([item])

        let reloaded = ClipboardStore(baseURL: directory).loadItems()
        XCTAssertEqual(reloaded.count, 1)
        XCTAssertEqual(reloaded.first?.type, .image)
        XCTAssertEqual(reloaded.first?.imageDimensions, stored.dimensions)
        XCTAssertEqual(reloaded.first?.thumbnailFileName, stored.thumbnailFileName)
    }

    func testMissingImageAssetIsDroppedOnLoad() throws {
        let directory = try TestFixtures.temporaryDirectory()
        defer { TestFixtures.remove(directory) }

        let store = ClipboardStore(baseURL: directory)
        let item = ClipboardItem(
            type: .image,
            content: "missing.png",
            plainText: "missing",
            contentHash: "missing",
            imageFileName: "missing.png",
            thumbnailFileName: "missing-thumb.png",
            imageDimensions: ImageDimensions(width: 10, height: 10)
        )
        store.saveNow([item])

        let reloaded = ClipboardStore(baseURL: directory).loadItems()
        XCTAssertTrue(reloaded.isEmpty)
    }
}
