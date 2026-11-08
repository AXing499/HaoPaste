//
//  HexColorTests.swift
//  HaoPasteTests
//

import XCTest
@testable import HaoPaste

final class HexColorTests: XCTestCase {
    func testRGBParsingAndRepresentations() throws {
        let color = try XCTUnwrap(HexColor(hex: "#FF8A5B"))
        XCTAssertEqual(color.red, 255)
        XCTAssertEqual(color.green, 138)
        XCTAssertEqual(color.blue, 91)
        XCTAssertEqual(color.alpha, 1)
        XCTAssertEqual(color.normalizedHex, "#FF8A5B")
        XCTAssertEqual(color.rgbString, "rgb(255, 138, 91)")
        XCTAssertEqual(color.hslString, "hsl(17, 100%, 68%)")
    }

    func testShortHexAndAlpha() throws {
        let short = try XCTUnwrap(HexColor(hex: "#abc"))
        XCTAssertEqual(short.normalizedHex, "#AABBCC")

        let alpha = try XCTUnwrap(HexColor(hex: "#FF000080"))
        XCTAssertEqual(alpha.alpha, 128.0 / 255.0, accuracy: 0.0001)
        XCTAssertEqual(alpha.normalizedHex, "#FF000080")
        XCTAssertEqual(alpha.rgbString, "rgba(255, 0, 0, 0.5)")
    }

    func testPrimaryHSLValues() throws {
        XCTAssertEqual(
            try XCTUnwrap(HexColor(hex: "#FF0000")).hslString,
            "hsl(0, 100%, 50%)"
        )
        XCTAssertEqual(
            try XCTUnwrap(HexColor(hex: "#00FF00")).hslString,
            "hsl(120, 100%, 50%)"
        )
        XCTAssertEqual(
            try XCTUnwrap(HexColor(hex: "#0000FF")).hslString,
            "hsl(240, 100%, 50%)"
        )
        XCTAssertEqual(
            try XCTUnwrap(HexColor(hex: "#808080")).hslString,
            "hsl(0, 0%, 50%)"
        )
    }

    func testAcceptsMissingHashAndRejectsInvalidInput() throws {
        XCTAssertEqual(
            try XCTUnwrap(HexColor(hex: "FF8A5B")).normalizedHex,
            "#FF8A5B"
        )
        XCTAssertNil(HexColor(hex: "#12"))
        XCTAssertNil(HexColor(hex: "#GGGGGG"))
        XCTAssertNil(HexColor(hex: ""))
    }
}
