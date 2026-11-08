//
//  TestSupport.swift
//  HaoPasteTests
//

import AppKit
import Foundation
@testable import HaoPaste

enum TestFixtures {
    static func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("HaoPasteTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    static func makeTextItem(
        _ text: String,
        type: ClipboardItemType = .text,
        isPinned: Bool = false,
        createdAt: Date = .now,
        sourceApp: SourceApplication? = nil
    ) -> ClipboardItem {
        ClipboardItem(
            type: type,
            content: text,
            plainText: text,
            isPinned: isPinned,
            createdAt: createdAt,
            sourceApp: sourceApp,
            contentHash: ContentHasher.text(text, type: type)
        )
    }

    @MainActor
    static func makePNGData(width: Int = 32, height: Int = 24) -> Data {
        let bitmap = NSBitmapImageRep(
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
        )!

        bitmap.size = NSSize(width: width, height: height)

        NSGraphicsContext.saveGraphicsState()
        if let context = NSGraphicsContext(bitmapImageRep: bitmap) {
            NSGraphicsContext.current = context
            NSColor.systemBlue.setFill()
            NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: height)).fill()
        }
        NSGraphicsContext.restoreGraphicsState()

        return bitmap.representation(using: .png, properties: [:])!
    }

    static func makeCustomPasteboard() -> NSPasteboard {
        NSPasteboard(name: NSPasteboard.Name("HaoPasteTests-\(UUID().uuidString)"))
    }
}
