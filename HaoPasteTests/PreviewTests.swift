//
//  PreviewTests.swift
//  HaoPasteTests
//

import AppKit
import UniformTypeIdentifiers
import XCTest
@testable import HaoPaste

@MainActor
final class PreviewTests: XCTestCase {
    func testPreviewStateLifecycle() {
        let state = PanelViewState()
        let item = TestFixtures.makeTextItem("Hello")

        XCTAssertFalse(state.isPreviewing)

        state.beginPreview(item)
        XCTAssertEqual(state.previewingItemID, item.id)
        XCTAssertEqual(state.selectedID, item.id)

        state.togglePreview(item)
        XCTAssertNil(state.previewingItemID)

        state.beginPreview(item)
        state.prepareForPresentation(firstItemID: item.id)
        XCTAssertFalse(state.isPreviewing)
        XCTAssertNil(state.previewingItemID)
    }

    func testPlainTextPreviewTruncatesLongContent() {
        let text = String(
            repeating: "a",
            count: ItemPreviewBuilder.maxPreviewCharacters + 25
        )
        let item = TestFixtures.makeTextItem(text)

        let preview = ItemPreviewBuilder.text(for: item, richText: nil)

        XCTAssertTrue(preview.isTruncated)
        XCTAssertEqual(preview.characterCount, text.count)
        XCTAssertLessThanOrEqual(
            preview.attributedString.length,
            ItemPreviewBuilder.maxPreviewCharacters + 3
        )
        XCTAssertTrue(preview.attributedString.string.hasSuffix("…"))
    }

    func testRichTextPreviewKeepsBoldAndNormalizesColor() {
        let payload = RichTextPayload(
            rtfData: Data(#"{\rtf1\ansi\b Bold\b0  plain}"#.utf8)
        )
        let item = TestFixtures.makeTextItem("Bold plain")

        let preview = ItemPreviewBuilder.text(for: item, richText: payload)

        XCTAssertFalse(preview.isTruncated)
        XCTAssertEqual(preview.attributedString.string, "Bold plain")

        let font = preview.attributedString.attribute(
            .font,
            at: 0,
            effectiveRange: nil
        ) as? NSFont
        XCTAssertTrue(
            font?.fontDescriptor.symbolicTraits.contains(.bold) ?? false
        )

        let color = preview.attributedString.attribute(
            .foregroundColor,
            at: 0,
            effectiveRange: nil
        ) as? NSColor
        XCTAssertEqual(color, NSColor.labelColor)
    }

    func testTextDragProviderCarriesPlainAndRichText() async throws {
        let payload = RichTextPayload(
            rtfData: Data(#"{\rtf1\ansi Rich Hello}"#.utf8)
        )
        let item = TestFixtures.makeTextItem("Rich Hello")

        let provider = ItemDragProvider.make(
            for: item,
            imageURL: nil,
            richText: payload
        )

        XCTAssertTrue(
            provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
        )
        XCTAssertTrue(
            provider.hasItemConformingToTypeIdentifier(UTType.rtf.identifier)
        )

        let plainData = try await loadData(from: provider, type: .plainText)
        let plainText = plainData.flatMap {
            String(data: $0, encoding: .utf8)
        }
        XCTAssertTrue(plainText?.contains("Rich Hello") ?? false)

        let rtfData = try await loadData(from: provider, type: .rtf)
        XCTAssertEqual(rtfData, payload.rtfData)
    }

    func testImageDragProviderCarriesPNGData() async throws {
        let directory = try TestFixtures.temporaryDirectory()
        defer { TestFixtures.remove(directory) }

        let store = ClipboardStore(baseURL: directory)
        let pngData = TestFixtures.makePNGData()
        let stored = try store.saveImage(data: pngData, id: UUID())
        let item = ClipboardItem(
            type: .image,
            content: stored.fileName,
            plainText: "图片",
            contentHash: ContentHasher.imageData(pngData),
            imageFileName: stored.fileName,
            thumbnailFileName: stored.thumbnailFileName,
            imageDimensions: stored.dimensions
        )
        let imageURL = try XCTUnwrap(store.imageURL(for: item))

        let provider = ItemDragProvider.make(
            for: item,
            imageURL: imageURL,
            richText: nil
        )

        XCTAssertTrue(
            provider.hasItemConformingToTypeIdentifier(UTType.png.identifier)
        )

        let data = try await loadData(from: provider, type: .png)
        XCTAssertEqual(data, pngData)
    }

    private func loadData(
        from provider: NSItemProvider,
        type: UTType
    ) async throws -> Data? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadDataRepresentation(
                forTypeIdentifier: type.identifier
            ) { data, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: data)
                }
            }
        }
    }
}
