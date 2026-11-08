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
        let service = OCRService { _ in
            counter.calls += 1
            return "HaoPaste OCR"
        }
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
        let emptyService = OCRService { _ in "" }
        emptyService.present(
            item: makeImageItem(),
            imageURL: URL(fileURLWithPath: "/tmp/empty.png")
        )
        await emptyService.waitForCurrentRecognition()
        XCTAssertEqual(emptyService.phase, .empty)

        let failedService = OCRService { _ in
            throw OCRError.invalidImage
        }
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
        let service = OCRService { _ in
            counter.calls += 1
            return "Original"
        }
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

    private func makeImageItem() -> ClipboardItem {
        ClipboardItem(
            type: .image,
            content: "image.png",
            plainText: "图片",
            contentHash: ContentHasher.imageData(Data("image".utf8)),
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
