//
//  LocalizationTests.swift
//  HaoPasteTests
//

import XCTest
@testable import HaoPaste

final class LocalizationTests: XCTestCase {
    private func bundle(for language: String) throws -> Bundle {
        let path = try XCTUnwrap(
            Bundle.main.path(forResource: language, ofType: "lproj")
        )
        return try XCTUnwrap(Bundle(path: path))
    }

    func testLocalizationBundlesArePresent() throws {
        for language in ["en", "zh-Hans"] {
            let bundle = try bundle(for: language)
            XCTAssertNotNil(
                bundle.path(forResource: "Localizable", ofType: "strings")
            )
            XCTAssertNotNil(
                bundle.path(forResource: "Localizable", ofType: "stringsdict")
            )
        }
    }

    @available(macOS 15.4, *)
    private func englishString(_ key: String) -> String {
        Bundle.main.localizedString(
            forKey: key,
            value: nil,
            table: nil,
            localizations: [Locale.Language(identifier: "en")]
        )
    }

    func testCoreEnglishTranslations() throws {
        guard #available(macOS 15.4, *) else {
            throw XCTSkip("Localization lookup requires macOS 15.4 or newer.")
        }

        XCTAssertEqual(englishString("复制为纯文本"), "Copy as Plain Text")
        XCTAssertEqual(englishString("剪贴板挂架"), "Clipboard Shelf")
        XCTAssertEqual(englishString("片段列表"), "Snippets")
    }

    func testEnglishCountStringsUsePluralRules() throws {
        guard #available(macOS 15.4, *) else {
            throw XCTSkip("Localization lookup requires macOS 15.4 or newer.")
        }

        let itemFormat = englishString("%d 条记录")
        XCTAssertEqual(
            String(
                format: itemFormat,
                locale: Locale(identifier: "en"),
                1
            ),
            "1 record"
        )
        XCTAssertEqual(
            String(
                format: itemFormat,
                locale: Locale(identifier: "en"),
                3
            ),
            "3 records"
        )

        let snippetFormat = englishString("%d 个片段")
        XCTAssertEqual(
            String(
                format: snippetFormat,
                locale: Locale(identifier: "en"),
                1
            ),
            "1 snippet"
        )
        XCTAssertEqual(
            String(
                format: snippetFormat,
                locale: Locale(identifier: "en"),
                2
            ),
            "2 snippets"
        )
    }
}
