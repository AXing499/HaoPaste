//
//  SearchMatcherTests.swift
//  HaoPasteTests
//

import XCTest
@testable import HaoPaste

final class SearchMatcherTests: XCTestCase {
    private func makeItems() -> [ClipboardItem] {
        let now = Date()
        return [
            TestFixtures.makeTextItem(
                "HaoPaste clipboard manager",
                isPinned: true,
                createdAt: now.addingTimeInterval(-200)
            ),
            TestFixtures.makeTextItem(
                "把复杂留给系统",
                createdAt: now.addingTimeInterval(-100),
                sourceApp: SourceApplication(bundleIdentifier: nil, name: "备忘录")
            ),
            TestFixtures.makeTextItem(
                "struct ClipboardPanel: View { }",
                type: .code,
                createdAt: now.addingTimeInterval(-50)
            ),
            TestFixtures.makeTextItem(
                "https://developer.apple.com/design",
                type: .url,
                createdAt: now.addingTimeInterval(-10),
                sourceApp: SourceApplication(
                    bundleIdentifier: "com.apple.Safari",
                    name: "Safari"
                )
            ),
            TestFixtures.makeTextItem(
                "{\"name\": \"HaoPaste\", \"enabled\": true}",
                type: .code,
                createdAt: now.addingTimeInterval(-300)
            )
        ]
    }

    func testChineseSubstringSearch() {
        let results = SearchMatcher().search(
            makeItems(),
            query: "复杂",
            filter: .all
        )
        XCTAssertTrue(results.contains { $0.plainText == "把复杂留给系统" })
    }

    func testPinyinFullAndInitials() {
        let matcher = SearchMatcher()
        let items = makeItems()

        XCTAssertTrue(
            matcher.search(items, query: "ba", filter: .all)
                .contains { $0.plainText == "把复杂留给系统" }
        )
        XCTAssertTrue(
            matcher.search(items, query: "bfz", filter: .all)
                .contains { $0.plainText == "把复杂留给系统" }
        )
        XCTAssertTrue(
            matcher.search(items, query: "fuza", filter: .all)
                .contains { $0.plainText == "把复杂留给系统" }
        )
    }

    func testFuzzyAndTokenMatching() {
        let matcher = SearchMatcher()
        let items = makeItems()

        XCTAssertTrue(
            matcher.search(items, query: "hpst", filter: .all)
                .contains { $0.plainText == "HaoPaste clipboard manager" }
        )
        XCTAssertTrue(
            matcher.search(items, query: "hao clipboard", filter: .all)
                .contains { $0.plainText == "HaoPaste clipboard manager" }
        )
    }

    func testSourceAndFormatSearch() {
        let matcher = SearchMatcher()
        let items = makeItems()

        let safari = matcher.search(items, query: "safari", filter: .all)
        XCTAssertEqual(safari.first?.type, .url)

        let json = matcher.search(items, query: "json", filter: .all)
        XCTAssertEqual(json.count, 1)
        XCTAssertEqual(json.first?.formatBadge, "JSON")
    }

    func testFilteringAndRelevanceOrdering() {
        let matcher = SearchMatcher()
        let items = makeItems()

        let codeResults = matcher.search(items, query: "haopaste", filter: .code)
        XCTAssertEqual(codeResults.count, 1)
        XCTAssertEqual(codeResults.first?.formatBadge, "JSON")

        let allResults = matcher.search(items, query: "haopaste", filter: .all)
        XCTAssertEqual(allResults.first?.plainText, "HaoPaste clipboard manager")
    }

    func testEmptyQuerySortsPinnedFirstThenNewest() {
        let matcher = SearchMatcher()
        let items = makeItems()
        let results = matcher.search(items, query: "   ", filter: .all)

        XCTAssertEqual(results.first?.isPinned, true)
        XCTAssertEqual(results.dropFirst().map(\.createdAt), results.dropFirst().map(\.createdAt).sorted(by: >))
    }
}
