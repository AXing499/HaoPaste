//
//  TranslationService.swift
//  HaoPaste
//
//  Observable translation state shared by the panel and settings.
//

import Foundation
import Observation

@MainActor
@Observable
final class TranslationService {
    enum Phase: Equatable {
        case idle
        case consentRequired
        case translating
        case success
        case failed
    }

    // MARK: - Long-lived dependencies

    let settings: TranslationSettingsStore
    let credentials: TranslationCredentialStoring

    @ObservationIgnored private let providers: [TranslationProviderID: any TranslationProvider]
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var cache: [String: TranslationResponse] = [:]
    @ObservationIgnored private var cacheOrder: [String] = []

    // MARK: - Observable state

    var isPresenting = false
    var sourceTitle = ""
    var sourceText = ""
    var targetLanguageID = ""
    var preferredProviderID: TranslationProviderID?
    var phase: Phase = .idle
    var resultText = ""
    var detectedSourceID: String?
    var activeProviderID: TranslationProviderID?
    var errorMessage: String?
    var consentProviders: [TranslationProviderID] = []
    var progressCurrent = 0
    var progressTotal = 0

    init(
        settings: TranslationSettingsStore? = nil,
        credentials: TranslationCredentialStoring? = nil,
        providers: [any TranslationProvider]? = nil
    ) {
        self.settings = settings ?? TranslationSettingsStore()
        self.credentials = credentials ?? KeychainTranslationCredentialStore()
        self.providers = TranslationProviderFactory.makeDictionary(
            providers: providers ?? TranslationProviderFactory.makeDefaultProviders()
        )
    }

    // MARK: - Derived state

    var targetLanguage: TranslationLanguage {
        TranslationLanguage.language(for: targetLanguageID)
            ?? settings.targetLanguage
    }

    var detectedLanguage: TranslationLanguage? {
        if let detectedSourceID,
           let language = TranslationLanguage.language(for: detectedSourceID) {
            return language
        }
        return TranslationLanguage.detect(in: sourceText)
    }

    var activeProvider: TranslationProviderDescriptor? {
        activeProviderID?.descriptor
    }

    var consentProviderNames: String {
        settingsProviderNames(for: consentProviders)
    }

    var availableProviderIDs: [TranslationProviderID] {
        settings.enabledProvidersInOrder.filter { id in
            guard providers[id] != nil else { return false }

            let descriptor = id.descriptor
            guard descriptor.requiresConfiguration else { return true }

            guard let credentials = credentials.credentials(for: id) else {
                return false
            }
            return credentials.hasValues(for: descriptor)
        }
    }

    var availableProviders: [TranslationProviderDescriptor] {
        availableProviderIDs.map(\.descriptor)
    }

    var isConsentBlocking: Bool {
        phase == .consentRequired
    }

    // MARK: - Presentation

    func present(item: ClipboardItem) {
        guard item.isTranslatable else { return }
        present(text: item.content, title: item.displayTitle)
    }

    func present(text: String, title: String) {
        task?.cancel()

        sourceTitle = title
        sourceText = text
        isPresenting = true
        preferredProviderID = nil
        phase = .idle
        resultText = ""
        detectedSourceID = nil
        activeProviderID = nil
        errorMessage = nil
        consentProviders = []
        progressCurrent = 0
        progressTotal = 0

        targetLanguageID = settings.targetLanguageID

        // If the copied text is already in the saved target language, offer the
        // most useful opposite direction for this session.
        if let detected = TranslationLanguage.detect(in: text),
           detected.id == targetLanguageID {
            if targetLanguageID.hasPrefix("zh") {
                targetLanguageID = TranslationLanguage.english.id
            } else if detected.id == "en" {
                targetLanguageID = TranslationLanguage.simplifiedChinese.id
            }
        }

        startTranslation()
    }

    func close() {
        task?.cancel()
        task = nil
        isPresenting = false
        phase = .idle
        consentProviders = []
        resultText = ""
        errorMessage = nil
        progressCurrent = 0
        progressTotal = 0
    }

    // MARK: - Actions

    func startTranslation(force: Bool = false) {
        task?.cancel()

        let trimmed = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            fail(L("没有可翻译的内容。"))
            return
        }

        let target = targetLanguage
        let providerIDs = preferredProviderID.map { [$0] } ?? availableProviderIDs

        guard !providerIDs.isEmpty else {
            fail(L("没有可用的翻译引擎，请先在设置中启用或配置一个引擎。"))
            return
        }

        let missingConsent = providerIDs.filter { !settings.hasConsent(for: $0) }
        if !missingConsent.isEmpty {
            consentProviders = missingConsent
            phase = .consentRequired
            return
        }

        consentProviders = []
        phase = .translating
        errorMessage = nil
        resultText = ""
        detectedSourceID = nil
        activeProviderID = nil
        progressCurrent = 0
        progressTotal = 0

        let text = sourceText
        task = Task { [weak self] in
            await self?.runTranslation(
                text: text,
                target: target,
                providerIDs: providerIDs,
                force: force
            )
        }
    }

    func retry() {
        startTranslation(force: true)
    }

    func grantConsentAndTranslate() {
        guard !consentProviders.isEmpty else {
            startTranslation(force: true)
            return
        }

        settings.grantConsent(to: Set(consentProviders))
        consentProviders = []
        startTranslation(force: true)
    }

    func setTargetLanguage(_ language: TranslationLanguage, persist: Bool = true) {
        targetLanguageID = language.id
        if persist {
            settings.setTargetLanguage(language)
        }

        guard isPresenting else { return }
        startTranslation(force: true)
    }

    func setPreferredProvider(_ id: TranslationProviderID?) {
        preferredProviderID = id

        guard isPresenting, phase != .consentRequired else { return }
        startTranslation(force: true)
    }

    func testProvider(
        _ id: TranslationProviderID,
        credentials: TranslationCredentials
    ) async throws {
        guard let provider = providers[id] else {
            throw TranslationError.invalidResponse
        }
        try await provider.testConnection(credentials)
    }

    /// Used by tests and visual QA to wait for the active request.
    func waitForCurrentTranslation() async {
        await task?.value
    }

    // MARK: - Provider execution

    private func runTranslation(
        text: String,
        target: TranslationLanguage,
        providerIDs: [TranslationProviderID],
        force: Bool
    ) async {
        var lastError: Error?

        for providerID in providerIDs {
            if Task.isCancelled { return }
            guard let provider = providers[providerID] else { continue }

            let providerCredentials = credentials.credentials(for: providerID)
                ?? TranslationCredentials()

            do {
                let response = try await translate(
                    text: text,
                    target: target,
                    provider: provider,
                    credentials: providerCredentials,
                    force: force
                )

                if Task.isCancelled { return }

                resultText = response.text
                detectedSourceID = response.detectedSourceID
                activeProviderID = providerID
                phase = .success
                progressCurrent = 0
                progressTotal = 0
                return
            } catch is CancellationError {
                return
            } catch {
                if Task.isCancelled { return }
                lastError = error
            }
        }

        if Task.isCancelled { return }

        let message: String
        if let error = lastError as? LocalizedError,
           let description = error.errorDescription {
            message = description
        } else if let lastError {
            message = lastError.localizedDescription
        } else {
            message = L("所有翻译引擎均未返回结果。")
        }
        fail(message)
    }

    private func translate(
        text: String,
        target: TranslationLanguage,
        provider: any TranslationProvider,
        credentials: TranslationCredentials,
        force: Bool
    ) async throws -> TranslationResponse {
        let cacheKey = "\(provider.id.rawValue)|\(target.id)|\(text)"
        if !force, let cached = cache[cacheKey] {
            return cached
        }

        let chunks = TextChunker.chunks(
            of: text,
            limit: provider.maxCharactersPerRequest
        )
        guard !chunks.isEmpty else { throw TranslationError.emptyText }

        progressTotal = chunks.count
        progressCurrent = 0

        var translatedChunks: [String] = []
        var detectedSourceID: String?

        for (index, chunk) in chunks.enumerated() {
            try Task.checkCancellation()
            progressCurrent = index + 1

            let response = try await provider.translate(
                TranslationRequest(
                    text: chunk,
                    source: nil,
                    target: target,
                    credentials: credentials
                )
            )

            if detectedSourceID == nil {
                detectedSourceID = response.detectedSourceID
            }
            translatedChunks.append(response.text)
        }

        let response = TranslationResponse(
            text: translatedChunks.joined(separator: "\n"),
            detectedSourceID: detectedSourceID
        )
        storeInCache(response, key: cacheKey)
        return response
    }

    private func fail(_ message: String) {
        phase = .failed
        errorMessage = message
        progressCurrent = 0
        progressTotal = 0
    }

    private func storeInCache(_ response: TranslationResponse, key: String) {
        if cache[key] == nil {
            cacheOrder.append(key)
        }
        cache[key] = response

        while cacheOrder.count > 50 {
            let removed = cacheOrder.removeFirst()
            cache.removeValue(forKey: removed)
        }
    }

    private func settingsProviderNames(
        for ids: [TranslationProviderID]
    ) -> String {
        ids.map(\.descriptor.name).joined(separator: L("、"))
    }
}

#if DEBUG
extension TranslationService {
    /// Seeds a deterministic success state for screenshots and visual QA.
    func seedPreview(
        sourceTitle: String,
        sourceText: String,
        target: TranslationLanguage,
        result: String,
        provider: TranslationProviderID
    ) {
        task?.cancel()
        self.sourceTitle = sourceTitle
        self.sourceText = sourceText
        self.targetLanguageID = target.id
        self.resultText = result
        self.activeProviderID = provider
        self.detectedSourceID = TranslationLanguage.detect(in: sourceText)?.id
        self.phase = .success
        self.isPresenting = true
        self.errorMessage = nil
        self.consentProviders = []
    }

    func seedConsentPreview(
        sourceTitle: String,
        sourceText: String,
        target: TranslationLanguage,
        providers: [TranslationProviderID]
    ) {
        task?.cancel()
        self.sourceTitle = sourceTitle
        self.sourceText = sourceText
        self.targetLanguageID = target.id
        self.resultText = ""
        self.activeProviderID = nil
        self.detectedSourceID = TranslationLanguage.detect(in: sourceText)?.id
        self.phase = .consentRequired
        self.isPresenting = true
        self.errorMessage = nil
        self.consentProviders = providers
    }

    func seedFailurePreview(
        sourceTitle: String,
        sourceText: String,
        target: TranslationLanguage,
        message: String
    ) {
        task?.cancel()
        self.sourceTitle = sourceTitle
        self.sourceText = sourceText
        self.targetLanguageID = target.id
        self.resultText = ""
        self.activeProviderID = nil
        self.detectedSourceID = TranslationLanguage.detect(in: sourceText)?.id
        self.phase = .failed
        self.isPresenting = true
        self.errorMessage = message
        self.consentProviders = []
    }
}
#endif
