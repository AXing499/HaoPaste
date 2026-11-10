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
        XCTAssertEqual(settings.appLanguage, .system)
        XCTAssertEqual(settings.maxUnpinnedItems, 200)
        XCTAssertEqual(settings.hotKey, .default)
        XCTAssertEqual(settings.translationHotKey, .translationDefault)
        XCTAssertFalse(settings.autoTranslateLatestOnOpen)
        XCTAssertTrue(settings.shelfEnabled)
        XCTAssertEqual(settings.shelfItemLimit, 8)
        XCTAssertEqual(settings.trashRetentionDays, 7)
        XCTAssertEqual(settings.shelfCardFallDuration, 0.75)
        XCTAssertEqual(settings.updateFeedURL, AppSettings.defaultUpdateFeedURL)
        XCTAssertEqual(settings.shelfEdge, .top)
        XCTAssertTrue(settings.capturesImages)
        XCTAssertTrue(settings.excludedApplications.isEmpty)
        XCTAssertNil(settings.hotKeyRegistrationError)
        XCTAssertNil(settings.translationHotKeyRegistrationError)
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
        settings.translationHotKey = HotKeyConfiguration(
            keyCode: UInt32(kVK_ANSI_L),
            carbonModifiers: UInt32(controlKey | optionKey)
        )
        settings.autoTranslateLatestOnOpen = false
        settings.shelfEnabled = false
        settings.shelfItemLimit = 10
        settings.shelfEdge = .left
        settings.trashRetentionDays = 30
        settings.shelfCardFallDuration = 1.0
        settings.updateFeedURL = "https://example.com/hao-paste/latest.json"
        settings.panelCopyBehavior = .stayOpen
        settings.shelfCopyBehavior = .hideAfterDelay
        settings.copyPlainTextOnly = true
        settings.appLanguage = .english

        let reloaded = AppSettings(defaults: defaults)
        XCTAssertEqual(reloaded.maxUnpinnedItems, 500)
        XCTAssertFalse(reloaded.capturesImages)
        XCTAssertEqual(reloaded.hotKey.displayString, "⌥⌘K")
        XCTAssertEqual(reloaded.translationHotKey.displayString, "⌃⌥L")
        XCTAssertFalse(reloaded.autoTranslateLatestOnOpen)
        XCTAssertFalse(reloaded.shelfEnabled)
        XCTAssertEqual(reloaded.shelfItemLimit, 10)
        XCTAssertEqual(reloaded.shelfEdge, .left)
        XCTAssertEqual(reloaded.trashRetentionDays, 30)
        XCTAssertEqual(reloaded.shelfCardFallDuration, 1.0)
        XCTAssertEqual(
            reloaded.updateFeedURL,
            "https://example.com/hao-paste/latest.json"
        )
        XCTAssertEqual(reloaded.panelCopyBehavior, .stayOpen)
        XCTAssertEqual(reloaded.shelfCopyBehavior, .hideAfterDelay)
        XCTAssertTrue(reloaded.copyPlainTextOnly)
        XCTAssertEqual(reloaded.appLanguage, .english)
    }

    func testShelfEdgeFallsBackToTop() throws {
        let suite = "HaoPasteTests-ShelfEdge-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set("diagonal", forKey: "settings.shelfEdge")

        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.shelfEdge, .top)

        settings.shelfEdge = .right
        XCTAssertEqual(
            AppSettings(defaults: defaults).shelfEdge,
            .right
        )
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
        XCTAssertEqual(settings.appLanguage, .system)
        XCTAssertEqual(settings.maxUnpinnedItems, 200)

        settings.maxUnpinnedItems = 123
        XCTAssertEqual(settings.maxUnpinnedItems, 200)
    }
}
