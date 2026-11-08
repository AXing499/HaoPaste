//
//  ContentClassifierTests.swift
//  HaoPasteTests
//

import XCTest
@testable import HaoPaste

final class ContentClassifierTests: XCTestCase {
    func testURLDetection() {
        XCTAssertEqual(ContentClassifier.classify("https://example.com/path?q=1"), .url)
        XCTAssertEqual(ContentClassifier.classify("http://example.com"), .url)
        XCTAssertEqual(ContentClassifier.classify("www.example.com"), .url)
        XCTAssertEqual(ContentClassifier.classify("mailto:hello@example.com"), .url)
        XCTAssertEqual(ContentClassifier.classify("not a url"), .text)
    }

    func testColorHexDetection() {
        XCTAssertEqual(ContentClassifier.classify("#FF8A5B"), .colorHex)
        XCTAssertEqual(ContentClassifier.classify("#abc"), .colorHex)
        XCTAssertEqual(ContentClassifier.classify("#FF8A5BCC"), .colorHex)
        XCTAssertEqual(ContentClassifier.classify("#12"), .text)
    }

    func testJSONDetection() {
        let json = """
        {
          "name": "HaoPaste",
          "enabled": true
        }
        """
        XCTAssertTrue(ContentClassifier.isJSON(json))
        XCTAssertEqual(ContentClassifier.classify(json), .code)
    }

    func testSwiftAndImportDetection() {
        XCTAssertEqual(
            ContentClassifier.classify("struct ClipboardPanel: View {\n    let id = UUID()\n}"),
            .code
        )
        XCTAssertEqual(ContentClassifier.classify("import Foundation"), .code)
        XCTAssertEqual(ContentClassifier.classify("let answer = 42\nprint(answer)"), .code)
    }

    func testProseIsNotMistakenForCode() {
        XCTAssertEqual(ContentClassifier.classify("let me know (please)"), .text)
        XCTAssertEqual(ContentClassifier.classify("This class is about design."), .text)
        XCTAssertEqual(ContentClassifier.classify("a normal sentence with a semicolon;"), .text)
    }

    func testSQLDetection() {
        XCTAssertEqual(ContentClassifier.classify("SELECT * FROM users;"), .code)
        XCTAssertEqual(ContentClassifier.classify("update accounts set active = 1;"), .code)
    }

    func testEmptyAndWhitespace() {
        XCTAssertEqual(ContentClassifier.classify(""), .text)
        XCTAssertEqual(ContentClassifier.classify("   \n\t"), .text)
    }
}
