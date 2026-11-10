//
//  TranslationServiceTests.swift
//  HaoPasteTests
//

import Foundation
import XCTest
@testable import HaoPaste

@MainActor
final class TranslationServiceTests: XCTestCase {
    func testFallbackToSecondProvider() async throws {
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = TranslationSettingsStore(defaults: defaults)
        settings.setEnabled(true, for: .googleUnofficial)
        settings.setEnabled(true, for: .bingUnofficial)
        settings.grantConsent(to: [.googleUnofficial, .bingUnofficial])

        let google = StubTranslationProvider(
            id: .googleUnofficial,
            maxCharactersPerRequest: 100
        ) { _ in
            throw TranslationError.service("Google failed")
        }
        let bing = StubTranslationProvider(
            id: .bingUnofficial,
            maxCharactersPerRequest: 100
        ) { _ in
            TranslationResponse(text: "你好", detectedSourceID: "en")
        }

        let service = TranslationService(
            settings: settings,
            credentials: InMemoryTranslationCredentialStore(),
            providers: [google, bing]
        )

        service.present(text: "Hello", title: "Hello")
        await service.waitForCurrentTranslation()

        XCTAssertEqual(service.phase, .success)
        XCTAssertEqual(service.resultText, "你好")
        XCTAssertEqual(service.activeProviderID, .bingUnofficial)
        XCTAssertEqual(google.callCount, 1)
        XCTAssertEqual(bing.callCount, 1)
    }

    func testConsentIsRequiredBeforeOnlineTranslation() async throws {
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = TranslationSettingsStore(defaults: defaults)
        settings.resetConsent()

        let provider = StubTranslationProvider(
            id: .googleUnofficial,
            maxCharactersPerRequest: 100
        ) { _ in
            TranslationResponse(text: "你好", detectedSourceID: "en")
        }

        let service = TranslationService(
            settings: settings,
            credentials: InMemoryTranslationCredentialStore(),
            providers: [provider]
        )

        service.present(text: "Hello", title: "Hello")
        await service.waitForCurrentTranslation()

        XCTAssertEqual(service.phase, .consentRequired)
        XCTAssertEqual(service.consentProviders, [.googleUnofficial])
        XCTAssertEqual(provider.callCount, 0)

        service.grantConsentAndTranslate()
        await service.waitForCurrentTranslation()

        XCTAssertEqual(service.phase, .success)
        XCTAssertEqual(service.resultText, "你好")
        XCTAssertTrue(settings.hasConsent(for: .googleUnofficial))
    }

    func testEnglishSourceSwitchesTargetToChinese() async throws {
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = TranslationSettingsStore(defaults: defaults)
        settings.setTargetLanguage(.english)
        settings.grantConsent(to: [.googleUnofficial])

        let provider = StubTranslationProvider(
            id: .googleUnofficial,
            maxCharactersPerRequest: 100
        ) { request in
            TranslationResponse(
                text: request.target.id == "zh-Hans" ? "你好，世界" : "不该出现",
                detectedSourceID: "en"
            )
        }

        let service = TranslationService(
            settings: settings,
            credentials: InMemoryTranslationCredentialStore(),
            providers: [provider]
        )

        service.present(
            text: "Hello world, this is a translation test.",
            title: "Hello"
        )
        await service.waitForCurrentTranslation()

        XCTAssertEqual(service.targetLanguageID, "zh-Hans")
        XCTAssertEqual(service.phase, .success)
        XCTAssertEqual(service.resultText, "你好，世界")
    }

    func testLongTextIsChunkedByProviderLimit() async throws {
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = TranslationSettingsStore(defaults: defaults)
        settings.grantConsent(to: [.googleUnofficial])

        let provider = StubTranslationProvider(
            id: .googleUnofficial,
            maxCharactersPerRequest: 5
        ) { request in
            TranslationResponse(text: request.text, detectedSourceID: nil)
        }

        let service = TranslationService(
            settings: settings,
            credentials: InMemoryTranslationCredentialStore(),
            providers: [provider]
        )

        service.present(text: "aaaa bbbb cccc", title: "Long")
        await service.waitForCurrentTranslation()

        XCTAssertEqual(service.phase, .success)
        XCTAssertEqual(provider.callCount, 3)
        XCTAssertEqual(service.resultText, "aaaa\nbbbb\ncccc")
    }

    func testTranslationCacheAvoidsDuplicateRequests() async throws {
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = TranslationSettingsStore(defaults: defaults)
        settings.grantConsent(to: [.googleUnofficial])

        let provider = StubTranslationProvider(
            id: .googleUnofficial,
            maxCharactersPerRequest: 100
        ) { _ in
            TranslationResponse(text: "Bonjour", detectedSourceID: "en")
        }

        let service = TranslationService(
            settings: settings,
            credentials: InMemoryTranslationCredentialStore(),
            providers: [provider]
        )

        service.present(text: "Hello", title: "Hello")
        await service.waitForCurrentTranslation()
        XCTAssertEqual(provider.callCount, 1)

        service.present(text: "Hello", title: "Hello")
        await service.waitForCurrentTranslation()
        XCTAssertEqual(provider.callCount, 1)
        XCTAssertEqual(service.resultText, "Bonjour")
    }

    func testUnconfiguredOfficialProviderIsSkipped() async throws {
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = TranslationSettingsStore(defaults: defaults)
        for id in settings.providerOrder {
            settings.setEnabled(false, for: id)
        }
        settings.setEnabled(true, for: .azure)
        settings.grantConsent(to: [.azure])

        let provider = StubTranslationProvider(
            id: .azure,
            maxCharactersPerRequest: 100
        ) { _ in
            TranslationResponse(text: "unused", detectedSourceID: nil)
        }

        let service = TranslationService(
            settings: settings,
            credentials: InMemoryTranslationCredentialStore(),
            providers: [provider]
        )

        service.present(text: "Hello", title: "Hello")
        await service.waitForCurrentTranslation()

        XCTAssertEqual(service.phase, .failed)
        XCTAssertEqual(provider.callCount, 0)
        XCTAssertEqual(
            service.errorMessage,
            L("没有可用的翻译引擎，请先在设置中启用或配置一个引擎。")
        )
    }

    func testSettingsPersistAndProviderOrderMoves() throws {
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = TranslationSettingsStore(defaults: defaults)
        store.setTargetLanguage(.english)
        store.setEnabled(false, for: .googleUnofficial)
        store.grantConsent(to: [.bingUnofficial])
        store.moveProvider(.googleUnofficial, by: 2)

        let reloaded = TranslationSettingsStore(defaults: defaults)

        XCTAssertEqual(reloaded.targetLanguageID, TranslationLanguage.english.id)
        XCTAssertFalse(reloaded.isEnabled(.googleUnofficial))
        XCTAssertTrue(reloaded.hasConsent(for: .bingUnofficial))
        XCTAssertEqual(
            reloaded.providerOrder.firstIndex(of: .bingUnofficial),
            0
        )
    }

    func testTextChunkerSplitsAndPreservesContent() {
        XCTAssertEqual(
            TextChunker.chunks(of: "short", limit: 100),
            ["short"]
        )

        let text = String(repeating: "a", count: 25)
        let chunks = TextChunker.chunks(of: text, limit: 10)

        XCTAssertEqual(chunks.count, 3)
        XCTAssertEqual(chunks.joined(), text)
    }

    // MARK: - Helpers

    private func makeDefaults() throws -> (UserDefaults, String) {
        let suite = "HaoPasteTests-Translation-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        return (defaults, suite)
    }
}

private final class StubTranslationProvider: TranslationProvider, @unchecked Sendable {
    let id: TranslationProviderID
    let maxCharactersPerRequest: Int

    private var storedRequests: [TranslationRequest] = []
    private let handler: (TranslationRequest) throws -> TranslationResponse

    init(
        id: TranslationProviderID,
        maxCharactersPerRequest: Int,
        handler: @escaping (TranslationRequest) throws -> TranslationResponse
    ) {
        self.id = id
        self.maxCharactersPerRequest = maxCharactersPerRequest
        self.handler = handler
    }

    var callCount: Int {
        storedRequests.count
    }

    func translate(_ request: TranslationRequest) async throws -> TranslationResponse {
        storedRequests.append(request)
        return try handler(request)
    }

    func testConnection(_ credentials: TranslationCredentials) async throws {}
}
