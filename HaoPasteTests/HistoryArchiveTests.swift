//
//  HistoryArchiveTests.swift
//  HaoPasteTests
//

import AppKit
import XCTest
@testable import HaoPaste

@MainActor
final class HistoryArchiveTests: XCTestCase {
    func testExportImportRoundTripAndDeduplication() throws {
        let root = try TestFixtures.temporaryDirectory()
        defer { TestFixtures.remove(root) }

        let sourceDirectory = root.appendingPathComponent("source", isDirectory: true)
        let destinationDirectory = root.appendingPathComponent("destination", isDirectory: true)
        let sourceStore = ClipboardStore(baseURL: sourceDirectory)
        let sourcePasteboard = TestFixtures.makeCustomPasteboard()

        let imageID = UUID()
        let imageData = TestFixtures.makePNGData()
        let storedImage = try sourceStore.saveImage(data: imageData, id: imageID)
        let sampleFile = root.appendingPathComponent("sample.txt")
        try Data("sample".utf8).write(to: sampleFile)
        let now = Date()
        let fileItem = ClipboardItem(
            type: .file,
            content: sampleFile.path,
            plainText: "sample.txt\n\(sampleFile.path)",
            createdAt: now.addingTimeInterval(-40),
            contentHash: ContentHasher.files([sampleFile.path]),
            filePaths: [sampleFile.path]
        )
        let richTextPayload = RichTextPayload(
            rtfData: Data(#"{\rtf1\ansi Rich Hello}"#.utf8),
            htmlData: Data("<b>Rich Hello</b>".utf8)
        )
        let richTextID = UUID()
        let richTextFileName = try sourceStore.saveRichText(
            richTextPayload,
            id: richTextID
        )
        let richTextItem = ClipboardItem(
            id: richTextID,
            type: .text,
            content: "Rich Hello",
            plainText: "Rich Hello",
            createdAt: now.addingTimeInterval(-35),
            contentHash: ContentHasher.richText(
                "Rich Hello",
                type: .text,
                rtf: richTextPayload.rtfData,
                html: richTextPayload.htmlData
            ),
            richTextFileName: richTextFileName
        )
        let sourceSnippets = [
            Snippet(title: "Email", content: "hello@example.com"),
            Snippet(title: "Signature", content: "—— HaoPaste")
        ]
        let sourceItems = [
            TestFixtures.makeTextItem(
                "pinned note",
                isPinned: true,
                createdAt: now.addingTimeInterval(-10)
            ),
            TestFixtures.makeTextItem(
                "let answer = 42",
                type: .code,
                createdAt: now.addingTimeInterval(-20)
            ),
            ClipboardItem(
                id: imageID,
                type: .image,
                content: storedImage.fileName,
                plainText: "图片 \(storedImage.dimensions.displayText)",
                createdAt: now.addingTimeInterval(-30),
                contentHash: ContentHasher.imageData(imageData),
                imageFileName: storedImage.fileName,
                thumbnailFileName: storedImage.thumbnailFileName,
                imageDimensions: storedImage.dimensions
            ),
            fileItem,
            richTextItem
        ]
        sourceStore.saveNow(sourceItems)

        let sourceManager = ClipboardManager(
            store: sourceStore,
            monitor: ClipboardMonitor(pasteboard: sourcePasteboard)
        )
        sourceManager.start()
        defer { sourceManager.shutdown() }

        let archiveURL = root.appendingPathComponent("backup.zip")
        let exportSummary = try sourceManager.exportHistory(
            to: archiveURL,
            snippets: sourceSnippets
        )
        XCTAssertEqual(exportSummary.itemCount, 5)
        XCTAssertEqual(exportSummary.imageCount, 1)
        XCTAssertEqual(exportSummary.snippetCount, 2)
        XCTAssertEqual(exportSummary.richTextCount, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: archiveURL.path))

        let destinationStore = ClipboardStore(baseURL: destinationDirectory)
        let destinationManager = ClipboardManager(
            store: destinationStore,
            monitor: ClipboardMonitor(pasteboard: TestFixtures.makeCustomPasteboard())
        )
        destinationManager.start()
        defer { destinationManager.shutdown() }

        let firstImport = try destinationManager.importHistory(from: archiveURL)
        XCTAssertEqual(firstImport.importedCount, 5)
        XCTAssertEqual(firstImport.mergedPinnedCount, 0)
        XCTAssertEqual(firstImport.skippedCount, 0)
        XCTAssertEqual(destinationManager.items.count, 5)
        XCTAssertEqual(destinationManager.pinnedCount, 1)

        let importedImage = try XCTUnwrap(
            destinationManager.items.first { $0.type == .image }
        )
        XCTAssertNotEqual(importedImage.imageFileName, storedImage.fileName)

        let imagesDirectory = destinationDirectory
            .appendingPathComponent("Images", isDirectory: true)
        let importedImageURL = imagesDirectory
            .appendingPathComponent(try XCTUnwrap(importedImage.imageFileName))
        XCTAssertTrue(FileManager.default.fileExists(atPath: importedImageURL.path))

        let importedThumbnailURL = imagesDirectory
            .appendingPathComponent(try XCTUnwrap(importedImage.thumbnailFileName))
        XCTAssertTrue(FileManager.default.fileExists(atPath: importedThumbnailURL.path))

        let secondImport = try destinationManager.importHistory(from: archiveURL)
        XCTAssertEqual(secondImport.importedCount, 0)
        XCTAssertEqual(secondImport.skippedCount, 5)
        XCTAssertEqual(destinationManager.items.count, 5)

        let importedFile = try XCTUnwrap(
            destinationManager.items.first { $0.type == .file }
        )
        XCTAssertEqual(importedFile.filePaths, [sampleFile.path])
        XCTAssertTrue(importedFile.hasAvailableFiles)

        let importedRichText = try XCTUnwrap(
            destinationManager.items.first { $0.hasRichText }
        )
        XCTAssertNotEqual(importedRichText.richTextFileName, richTextFileName)
        XCTAssertEqual(
            destinationStore.loadRichText(for: importedRichText),
            richTextPayload
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: try XCTUnwrap(
                    destinationStore.richTextURL(for: importedRichText)
                ).path
            )
        )

        let destinationSnippets = SnippetManager(
            store: SnippetStore(baseURL: destinationDirectory)
        )
        let snippetMerge = destinationSnippets.mergeImported(firstImport.snippets)
        XCTAssertEqual(firstImport.snippets.count, 2)
        XCTAssertEqual(snippetMerge.added, 2)
        XCTAssertEqual(destinationSnippets.snippets.count, 2)

        let secondSnippetMerge = destinationSnippets.mergeImported(secondImport.snippets)
        XCTAssertEqual(secondSnippetMerge.added, 0)
        XCTAssertEqual(secondSnippetMerge.skipped, 2)
    }

    func testImportRejectsMissingHistoryFile() throws {
        let root = try TestFixtures.temporaryDirectory()
        defer { TestFixtures.remove(root) }

        let sourceDirectory = root.appendingPathComponent("source", isDirectory: true)
        let destinationDirectory = root.appendingPathComponent("destination", isDirectory: true)
        let sourceStore = ClipboardStore(baseURL: sourceDirectory)
        let sourcePasteboard = TestFixtures.makeCustomPasteboard()
        let sourceManager = ClipboardManager(
            store: sourceStore,
            monitor: ClipboardMonitor(pasteboard: sourcePasteboard)
        )
        sourceManager.start()
        defer { sourceManager.shutdown() }

        let archiveURL = root.appendingPathComponent("empty.zip")
        let emptyPayload = root.appendingPathComponent("Empty", isDirectory: true)
        try FileManager.default.createDirectory(at: emptyPayload, withIntermediateDirectories: true)
        FileManager.default.createFile(
            atPath: emptyPayload.appendingPathComponent("not-history.txt").path,
            contents: Data("nope".utf8)
        )

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--keepParent", emptyPayload.path, archiveURL.path]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)

        let destinationStore = ClipboardStore(baseURL: destinationDirectory)
        let destinationManager = ClipboardManager(
            store: destinationStore,
            monitor: ClipboardMonitor(pasteboard: TestFixtures.makeCustomPasteboard())
        )
        destinationManager.start()
        defer { destinationManager.shutdown() }

        XCTAssertThrowsError(try destinationManager.importHistory(from: archiveURL))
    }
}
