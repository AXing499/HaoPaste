//
//  HotKeyConfigurationTests.swift
//  HaoPasteTests
//

import Carbon.HIToolbox
import XCTest
@testable import HaoPaste

final class HotKeyConfigurationTests: XCTestCase {
    func testDefaultConfiguration() {
        let configuration = HotKeyConfiguration.default
        XCTAssertTrue(configuration.isValid)
        XCTAssertEqual(configuration.displayString, "⌃⌥V")
    }

    func testDefaultShortcutFamily() {
        XCTAssertEqual(HotKeyConfiguration.default.displayString, "⌃⌥V")
        XCTAssertEqual(HotKeyConfiguration.translationDefault.displayString, "⌃⌥T")
        XCTAssertEqual(
            HotKeyConfiguration.pasteStackNextDefault.displayString,
            "⌃⌥N"
        )
        XCTAssertEqual(
            HotKeyConfiguration.screenshotTranslationDefault.displayString,
            "⌃⌥S"
        )
    }

    func testDefaultShortcutsAreUnique() {
        let defaults = [
            HotKeyConfiguration.default,
            HotKeyConfiguration.translationDefault,
            HotKeyConfiguration.pasteStackNextDefault,
            HotKeyConfiguration.screenshotTranslationDefault
        ]
        XCTAssertEqual(
            Set(defaults.map { "\($0.keyCode)-\($0.carbonModifiers)" }).count,
            defaults.count
        )
    }

    func testConfigurationRequiresPrimaryModifier() {
        let invalid = HotKeyConfiguration(
            keyCode: UInt32(kVK_ANSI_K),
            carbonModifiers: UInt32(shiftKey)
        )
        XCTAssertFalse(invalid.isValid)
    }

    func testEscapeIsRejected() {
        let escape = HotKeyConfiguration(
            keyCode: UInt32(kVK_Escape),
            carbonModifiers: UInt32(cmdKey)
        )
        XCTAssertFalse(escape.isValid)
    }

    func testDisplayOrderAndKeyNames() {
        let configuration = HotKeyConfiguration(
            keyCode: UInt32(kVK_ANSI_K),
            carbonModifiers: UInt32(controlKey | shiftKey)
        )
        XCTAssertEqual(configuration.displayString, "⌃⇧K")

        let f5 = HotKeyConfiguration(
            keyCode: UInt32(kVK_F5),
            carbonModifiers: UInt32(cmdKey | optionKey)
        )
        XCTAssertEqual(f5.displayString, "⌥⌘F5")
    }

    func testCarbonModifierConversion() {
        let modifiers = HotKeyConfiguration.carbonModifiers(
            from: [.command, .option, .control, .shift]
        )
        XCTAssertEqual(
            modifiers,
            UInt32(cmdKey | optionKey | controlKey | shiftKey)
        )
    }
}
