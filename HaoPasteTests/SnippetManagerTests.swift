//
//  SnippetManagerTests.swift
//  HaoPasteTests
//

import XCTest
@testable import HaoPaste

@MainActor
final class SnippetManagerTests: XCTestCase {
    func testCreateUpdateDeleteFilterAndPersistence() throws {
        let directory = try TestFixtures.temporaryDirectory()
        defer { TestFixtures.remove(directory) }

        let manager = SnippetManager(
            store: SnippetStore(baseURL: directory)
        )

        let first = try XCTUnwrap(
            manager.create(title: "邮箱", content: "hello@example.com")
        )
        _ = manager.create(title: "签名", content: "—— HaoPaste")

        XCTAssertEqual(manager.snippets.count, 2)
        XCTAssertEqual(manager.filtered(query: "hello").first?.id, first.id)

        manager.update(first, title: "工作邮箱", content: "team@example.com")
        XCTAssertEqual(
            manager.snippets.first(where: { $0.id == first.id })?.title,
            "工作邮箱"
        )

        let reloaded = SnippetManager(
            store: SnippetStore(baseURL: directory)
        )
        XCTAssertEqual(reloaded.snippets.count, 2)
        XCTAssertTrue(reloaded.snippets.contains { $0.content == "team@example.com" })

        reloaded.delete(try XCTUnwrap(reloaded.snippets.first { $0.id == first.id }))
        XCTAssertEqual(reloaded.snippets.count, 1)

        let reloadedAgain = SnippetManager(
            store: SnippetStore(baseURL: directory)
        )
        XCTAssertEqual(reloadedAgain.snippets.count, 1)
    }

    func testMergeImportedSnippets() throws {
        let directory = try TestFixtures.temporaryDirectory()
        defer { TestFixtures.remove(directory) }

        let manager = SnippetManager(
            store: SnippetStore(baseURL: directory)
        )
        let existing = try XCTUnwrap(
            manager.create(title: "Email", content: "old@example.com")
        )

        let newerExisting = Snippet(
            id: existing.id,
            title: "Email",
            content: "new@example.com",
            createdAt: existing.createdAt,
            updatedAt: Date().addingTimeInterval(10)
        )
        let newSnippet = Snippet(
            title: "Signature",
            content: "—— HaoPaste"
        )
        let duplicateContent = Snippet(
            title: "Signature",
            content: "—— HaoPaste"
        )

        let summary = manager.mergeImported([
            newerExisting,
            newSnippet,
            duplicateContent
        ])

        XCTAssertEqual(summary.updated, 1)
        XCTAssertEqual(summary.added, 1)
        XCTAssertEqual(summary.skipped, 1)
        XCTAssertEqual(manager.snippets.count, 2)
        XCTAssertTrue(manager.snippets.contains { $0.content == "new@example.com" })
    }

    func testPanelStateSnippetSelection() {
        let state = PanelViewState()
        let snippets = [
            Snippet(title: "One", content: "1"),
            Snippet(title: "Two", content: "2"),
            Snippet(title: "Three", content: "3")
        ]

        state.ensureSnippetSelection(in: snippets)
        XCTAssertEqual(state.selectedSnippetID, snippets[0].id)

        state.moveSnippetSelection(in: snippets, by: 1)
        XCTAssertEqual(state.selectedSnippetID, snippets[1].id)

        state.moveSnippetSelection(in: snippets, by: 10)
        XCTAssertEqual(state.selectedSnippetID, snippets[2].id)

        XCTAssertEqual(state.selectedSnippet(in: snippets)?.title, "Three")

        state.ensureSnippetSelection(in: [])
        XCTAssertNil(state.selectedSnippetID)
    }
}
