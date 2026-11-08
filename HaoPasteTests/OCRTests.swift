//
//  OCRTests.swift
//  HaoPasteTests
//

import AppKit
import XCTest
@testable import HaoPaste

@MainActor
final class OCRTests: XCTestCase {
    func testOCRServiceRecognizesAndCaches() async throws {
        let counter = OCRCounter()
        let service = OCRService(
            recognizer: { _, _ in
                counter.calls += 1
                return "HaoPaste OCR"
            },
            cache: InMemoryOCRCache()
        )
        let item = makeImageItem()
        let url = URL(fileURLWithPath: "/tmp/haopaste-ocr-test.png")

        service.present(item: item, imageURL: url)
        await service.waitForCurrentRecognition()

        XCTAssertEqual(service.phase, .success)
        XCTAssertEqual(service.text, "HaoPaste OCR")
        XCTAssertEqual(counter.calls, 1)

        service.present(item: item, imageURL: url)
        await service.waitForCurrentRecognition()
        XCTAssertEqual(counter.calls, 1)

        service.recognize(force: true)
        await service.waitForCurrentRecognition()
        XCTAssertEqual(counter.calls, 2)
    }

    func testOCREmptyAndFailureStates() async throws {
        let emptyService = OCRService(
            recognizer: { _, _ in "" },
            cache: InMemoryOCRCache()
        )
        emptyService.present(
            item: makeImageItem(),
            imageURL: URL(fileURLWithPath: "/tmp/empty.png")
        )
        await emptyService.waitForCurrentRecognition()
        XCTAssertEqual(emptyService.phase, .empty)

        let failedService = OCRService(
            recognizer: { _, _ in
                throw OCRError.invalidImage
            },
            cache: InMemoryOCRCache()
        )
        failedService.present(
            item: makeImageItem(),
            imageURL: URL(fileURLWithPath: "/tmp/failed.png")
        )
        await failedService.waitForCurrentRecognition()
        XCTAssertEqual(failedService.phase, .failed)
        XCTAssertEqual(failedService.errorMessage, "无法读取这张图片。")
    }

    func testEditedTextIsReusedForSameItem() async throws {
        let counter = OCRCounter()
        let service = OCRService(
            recognizer: { _, _ in
                counter.calls += 1
                return "Original"
            },
            cache: InMemoryOCRCache()
        )
        let item = makeImageItem()
        let url = URL(fileURLWithPath: "/tmp/edited.png")

        service.present(item: item, imageURL: url)
        await service.waitForCurrentRecognition()
        service.updateText("Edited text")
        service.close()

        service.present(item: item, imageURL: url)
        await service.waitForCurrentRecognition()

        XCTAssertEqual(service.text, "Edited text")
        XCTAssertEqual(counter.calls, 1)
    }

    func testBatchOCRRecognizesAndReusesCache() async throws {
        let counter = OCRCounter()
        let cache = InMemoryOCRCache()
        let service = OCRService(
            recognizer: { url, _ in
                counter.calls += 1
                return "Text from \(url.lastPathComponent)"
            },
            cache: cache
        )

        let firstItem = makeImageItem(hash: "hash-one")
        let secondItem = makeImageItem(hash: "hash-two")
        let firstURL = URL(fileURLWithPath: "/tmp/one.png")
        let secondURL = URL(fileURLWithPath: "/tmp/two.png")

        service.presentBatch(items: [
            (firstItem, firstURL),
            (secondItem, secondURL)
        ])
        await service.waitForCurrentRecognition()

        XCTAssertTrue(service.isBatchMode)
        XCTAssertEqual(service.batchEntries.count, 2)
        XCTAssertTrue(service.batchEntries.allSatisfy { $0.phase == .success })
        XCTAssertEqual(service.batchProgressCurrent, 2)
        XCTAssertEqual(counter.calls, 2)
        XCTAssertEqual(service.batchEntries[0].text, "Text from one.png")

        let reloaded = OCRService(
            recognizer: { _, _ in
                XCTFail("Cache should avoid recognition")
                return "unexpected"
            },
            cache: cache
        )
        reloaded.presentBatch(items: [
            (firstItem, firstURL),
            (secondItem, secondURL)
        ])
        await reloaded.waitForCurrentRecognition()

        XCTAssertEqual(reloaded.batchEntries[0].text, "Text from one.png")
        XCTAssertEqual(reloaded.batchEntries[1].text, "Text from two.png")
        XCTAssertEqual(reloaded.batchProgressCurrent, 2)
    }

    func testDiskCachePersistsAndClears() throws {
        let directory = try TestFixtures.temporaryDirectory()
        defer { TestFixtures.remove(directory) }

        let cache = OCRDiskCache(directoryURL: directory)
        cache.save("HaoPaste OCR", key: "hash-one-automatic")

        let reloaded = OCRDiskCache(directoryURL: directory)
        XCTAssertEqual(reloaded.load(key: "hash-one-automatic"), "HaoPaste OCR")

        reloaded.removeAll()
        XCTAssertNil(reloaded.load(key: "hash-one-automatic"))
    }

    func testRecognitionLanguagePersists() throws {
        let suite = "HaoPasteTests-OCR-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let service = OCRService(
            recognizer: { _, _ in "" },
            cache: InMemoryOCRCache(),
            defaults: defaults
        )
        XCTAssertEqual(service.recognitionLanguage, .automatic)

        service.recognitionLanguage = .simplifiedChinese

        let reloaded = OCRService(
            recognizer: { _, _ in "" },
            cache: InMemoryOCRCache(),
            defaults: defaults
        )
        XCTAssertEqual(reloaded.recognitionLanguage, .simplifiedChinese)
    }

    func testVisionRecognizesGeneratedEnglishImage() async throws {
        let directory = try TestFixtures.temporaryDirectory()
        defer { TestFixtures.remove(directory) }

        let url = directory.appendingPathComponent("ocr-fixture.png")
        try makeTextImage(text: "HaoPaste OCR 123")
            .write(to: url)

        let text = try await VisionTextRecognizer.recognize(url: url)

        XCTAssertTrue(
            text.localizedCaseInsensitiveContains("HaoPaste"),
            "Unexpected OCR result: \(text)"
        )
    }

    func testVisionRecognizesGeneratedChineseImage() async throws {
        let directory = try TestFixtures.temporaryDirectory()
        defer { TestFixtures.remove(directory) }

        let url = directory.appendingPathComponent("ocr-chinese-fixture.png")
        try makeTextImage(text: "你好世界")
            .write(to: url)

        let text = try await VisionTextRecognizer.recognize(url: url)

        XCTAssertTrue(
            text.contains("你好") || text.contains("世界"),
            "Unexpected OCR result: \(text)"
        )
    }

    // MARK: - Helpers

    private func makeImageItem(hash: String = "image") -> ClipboardItem {
        ClipboardItem(
            type: .image,
            content: "image.png",
            plainText: "图片",
            contentHash: hash,
            imageFileName: "image.png"
        )
    }

    private func makeTextImage(text: String) throws -> Data {
        let width = 1_000
        let height = 320

        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw OCRError.invalidImage
        }

        bitmap.size = NSSize(width: width, height: height)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSColor.white.setFill()
        NSBezierPath(
            rect: NSRect(x: 0, y: 0, width: width, height: height)
        ).fill()

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 72, weight: .bold),
            .foregroundColor: NSColor.black
        ]
        (text as NSString).draw(
            at: NSPoint(x: 40, y: 120),
            withAttributes: attributes
        )
        NSGraphicsContext.restoreGraphicsState()

        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw OCRError.invalidImage
        }
        return data
    }
}

private final class OCRCounter: @unchecked Sendable {
    var calls = 0
}
