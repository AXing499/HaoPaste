//
//  AppSettingsTests.swift
//  HaoPasteTests
//

import Carbon.HIToolbox
import XCTest
@testable import HaoPaste

@MainActor
final class AppSettingsTests: XCTestCase {
    func testDefaultSettings() throws {
        let suiteName = "HaoPasteTests.settings.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.maxUnpinnedItems, 200)
        XCTAssertEqual(settings.hotKey, .default)
        XCTAssertTrue(settings.capturesImages)
        XCTAssertTrue(settings.excludedApplications.isEmpty)
        XCTAssertNil(settings.hotKeyRegistrationError)
    }

    func testSettingsPersistence() throws {
        let suiteName = "HaoPasteTests.settings.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)
        settings.maxUnpinnedItems = 500
        settings.capturesImages = false
        settings.hotKey = HotKeyConfiguration(
            keyCode: UInt32(kVK_ANSI_K),
            carbonModifiers: UInt32(cmdKey | optionKey)
        )

        let reloaded = AppSettings(defaults: defaults)
        XCTAssertEqual(reloaded.maxUnpinnedItems, 500)
        XCTAssertFalse(reloaded.capturesImages)
        XCTAssertEqual(reloaded.hotKey.displayString, "⌥⌘K")
    }

    func testExcludedApplicationsPersistAndDeduplicate() throws {
        let suiteName = "HaoPasteTests.settings.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)
        let safari = ExcludedApplication(
            bundleIdentifier: "com.apple.Safari",
            name: "Safari"
        )
        let terminal = ExcludedApplication(
            bundleIdentifier: "com.apple.Terminal",
            name: "终端"
        )

        settings.addExcludedApplications([safari, safari, terminal])
        XCTAssertEqual(settings.excludedApplications.count, 2)

        let reloaded = AppSettings(defaults: defaults)
        XCTAssertEqual(reloaded.excludedApplications.count, 2)

        reloaded.removeExcludedApplication(safari)
        XCTAssertEqual(reloaded.excludedApplications.map(\.name), ["终端"])
    }

    func testSourceExclusionMatching() throws {
        let suiteName = "HaoPasteTests.settings.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)
        settings.addExcludedApplications([
            ExcludedApplication(
                bundleIdentifier: "com.apple.Safari",
                name: "Safari"
            ),
            ExcludedApplication(bundleIdentifier: nil, name: "LegacyApp")
        ])

        XCTAssertTrue(
            settings.isSourceExcluded(
                SourceApplication(
                    bundleIdentifier: "com.apple.Safari",
                    name: "Safari"
                )
            )
        )
        XCTAssertTrue(
            settings.isSourceExcluded(
                SourceApplication(bundleIdentifier: nil, name: "LegacyApp")
            )
        )
        XCTAssertFalse(
            settings.isSourceExcluded(
                SourceApplication(
                    bundleIdentifier: "com.apple.Notes",
                    name: "Safari"
                )
            )
        )
        XCTAssertFalse(
            settings.isSourceExcluded(
                SourceApplication(
                    bundleIdentifier: "com.apple.TextEdit",
                    name: "TextEdit"
                )
            )
        )
    }

    func testInvalidHistoryLimitFallsBackToDefault() throws {
        let suiteName = "HaoPasteTests.settings.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(123, forKey: "settings.maxUnpinnedItems")
        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.maxUnpinnedItems, 200)

        settings.maxUnpinnedItems = 123
        XCTAssertEqual(settings.maxUnpinnedItems, 200)
    }
}
