//
//  TranslationSettingsStore.swift
//  HaoPaste
//
//  Persistent preferences for translation engines, ordering and consent.
//

import Foundation
import Observation

@MainActor
@Observable
final class TranslationSettingsStore {
    private enum Keys {
        static let targetLanguage = "translation.targetLanguage"
        static let providerOrder = "translation.providerOrder"
        static let enabledProviders = "translation.enabledProviders"
        static let consentedProviders = "translation.consentedProviders"
    }

    static let defaultProviderOrder: [TranslationProviderID] = [
        .googleUnofficial,
        .bingUnofficial,
        .deeplUnofficial,
        .azure,
        .deeplAPI,
        .baidu,
        .googleCloud
    ]

    static let defaultEnabledProviders: Set<TranslationProviderID> = [
        .googleUnofficial,
        .bingUnofficial
    ]

    var targetLanguageID: String {
        didSet {
            guard oldValue != targetLanguageID else { return }
            defaults.set(targetLanguageID, forKey: Keys.targetLanguage)
        }
    }

    private(set) var providerOrder: [TranslationProviderID] {
        didSet {
            persist(providerOrder.map(\.rawValue), forKey: Keys.providerOrder)
        }
    }

    private(set) var enabledProviderIDs: Set<TranslationProviderID> {
        didSet {
            persist(
                enabledProviderIDs.map(\.rawValue).sorted(),
                forKey: Keys.enabledProviders
            )
        }
    }

    private(set) var consentedProviderIDs: Set<TranslationProviderID> {
        didSet {
            persist(
                consentedProviderIDs.map(\.rawValue).sorted(),
                forKey: Keys.consentedProviders
            )
        }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let storedTarget = defaults.string(forKey: Keys.targetLanguage)
        let resolvedTarget = storedTarget.flatMap(TranslationLanguage.language(for:))
            ?? TranslationLanguage.defaultTarget
        targetLanguageID = resolvedTarget.id

        let storedOrder = Self.decodeIDs(
            defaults.data(forKey: Keys.providerOrder)
        ) ?? []
        var order = storedOrder
        for id in Self.defaultProviderOrder where !order.contains(id) {
            order.append(id)
        }
        if order.isEmpty {
            order = Self.defaultProviderOrder
        }
        providerOrder = order

        if defaults.object(forKey: Keys.enabledProviders) == nil {
            enabledProviderIDs = Self.defaultEnabledProviders
        } else {
            enabledProviderIDs = Set(
                Self.decodeIDs(defaults.data(forKey: Keys.enabledProviders)) ?? []
            )
        }

        consentedProviderIDs = Set(
            Self.decodeIDs(defaults.data(forKey: Keys.consentedProviders)) ?? []
        )
    }

    // MARK: - Derived values

    var targetLanguage: TranslationLanguage {
        TranslationLanguage.language(for: targetLanguageID)
            ?? TranslationLanguage.defaultTarget
    }

    var enabledProvidersInOrder: [TranslationProviderID] {
        providerOrder.filter { enabledProviderIDs.contains($0) }
    }

    func isEnabled(_ id: TranslationProviderID) -> Bool {
        enabledProviderIDs.contains(id)
    }

    func hasConsent(for id: TranslationProviderID) -> Bool {
        consentedProviderIDs.contains(id)
    }

    // MARK: - Mutations

    func setTargetLanguage(_ language: TranslationLanguage) {
        targetLanguageID = language.id
    }

    func setEnabled(_ enabled: Bool, for id: TranslationProviderID) {
        if enabled {
            enabledProviderIDs.insert(id)
        } else {
            enabledProviderIDs.remove(id)
            consentedProviderIDs.remove(id)
        }
    }

    func moveProvider(_ id: TranslationProviderID, by offset: Int) {
        guard let index = providerOrder.firstIndex(of: id) else { return }
        let target = min(max(index + offset, 0), providerOrder.count - 1)
        guard target != index else { return }

        var order = providerOrder
        order.remove(at: index)
        order.insert(id, at: target)
        providerOrder = order
    }

    func grantConsent(to ids: Set<TranslationProviderID>) {
        consentedProviderIDs.formUnion(ids)
    }

    func resetConsent() {
        consentedProviderIDs.removeAll()
    }

    // MARK: - Persistence helpers

    private func persist(_ ids: [String], forKey key: String) {
        guard let data = try? JSONEncoder().encode(ids) else { return }
        defaults.set(data, forKey: key)
    }

    private static func decodeIDs(_ data: Data?) -> [TranslationProviderID]? {
        guard let data,
              let rawValues = try? JSONDecoder().decode([String].self, from: data)
        else {
            return nil
        }
        return rawValues.compactMap(TranslationProviderID.init(rawValue:))
    }
}
