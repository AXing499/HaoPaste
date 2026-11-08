//
//  FileClipboardTests.swift
//  HaoPasteTests
//

import AppKit
import XCTest
@testable import HaoPaste

@MainActor
final class FileClipboardTests: XCTestCase {
    func testFileItemPresentationAndFiltering() throws {
        let directory = try TestFixtures.temporaryDirectory()
        defer { TestFixtures.remove(directory) }

        let first = directory.appendingPathComponent("first.txt")
        let second = directory.appendingPathComponent("second.pdf")
        try Data("first".utf8).write(to: first)
        try Data("second".utf8).write(to: second)

        let paths = [first.path, second.path]
        let item = ClipboardItem(
            type: .file,
            content: paths.joined(separator: "\n"),
            plainText: "first.txt\nsecond.pdf\n\(paths.joined(separator: "\n"))",
            contentHash: ContentHasher.files(paths),
            filePaths: paths
        )

        XCTAssertEqual(item.displayTitle, "first.txt、second.pdf")
        XCTAssertEqual(item.formatBadge, "文件")
        XCTAssertEqual(item.detailBadge, "2 个文件")
        XCTAssertTrue(item.hasAvailableFiles)
        XCTAssertFalse(item.hasMissingFiles)
        XCTAssertTrue(ClipboardFilter.file.matches(item))
        XCTAssertTrue(item.matches("first.txt"))
        XCTAssertFalse(ClipboardFilter.text.matches(item))

        XCTAssertEqual(
            ContentHasher.files(paths),
            ContentHasher.files(paths.reversed())
        )
    }

    func testMissingFileState() {
        let item = ClipboardItem(
            type: .file,
            content: "/tmp/HaoPaste-missing.txt",
            plainText: "HaoPaste-missing.txt",
            contentHash: ContentHasher.files(["/tmp/HaoPaste-missing.txt"]),
            filePaths: ["/tmp/HaoPaste-missing.txt"]
        )

        XCTAssertFalse(item.hasAvailableFiles)
        XCTAssertTrue(item.hasMissingFiles)
        XCTAssertEqual(item.detailBadge, "文件已丢失")
    }

    func testCopyFileItemWritesFileURLs() throws {
        let directory = try TestFixtures.temporaryDirectory()
        defer { TestFixtures.remove(directory) }

        let first = directory.appendingPathComponent("copy-a.txt")
        let second = directory.appendingPathComponent("copy-b.txt")
        try Data("a".utf8).write(to: first)
        try Data("b".utf8).write(to: second)

        let paths = [first.path, second.path]
        let item = ClipboardItem(
            type: .file,
            content: paths.joined(separator: "\n"),
            plainText: "copy-a.txt\ncopy-b.txt",
            contentHash: ContentHasher.files(paths),
            filePaths: paths
        )

        let pasteboard = TestFixtures.makeCustomPasteboard()
        let store = ClipboardStore(baseURL: directory)
        let manager = ClipboardManager(
            store: store,
            monitor: ClipboardMonitor(pasteboard: pasteboard)
        )

        XCTAssertTrue(manager.copyToPasteboard(item))

        let objects = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [NSURL]
        let copiedPaths = Set((objects ?? []).map { ($0 as URL).standardizedFileURL.path })
        XCTAssertEqual(copiedPaths, Set(paths))
    }
}
