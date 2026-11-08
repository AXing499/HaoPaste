//
//  TranslationCredentialStore.swift
//  HaoPaste
//
//  API credentials live in the macOS Keychain, never in backups or defaults.
//

import Foundation
import Security

@MainActor
protocol TranslationCredentialStoring: AnyObject {
    func credentials(for id: TranslationProviderID) -> TranslationCredentials?
    func save(_ credentials: TranslationCredentials, for id: TranslationProviderID)
    func remove(for id: TranslationProviderID)
    func hasCredentials(for id: TranslationProviderID) -> Bool
}

@MainActor
final class KeychainTranslationCredentialStore: TranslationCredentialStoring {
    private let service: String

    init(service: String = "com.hao.HaoPaste.translation") {
        self.service = service
    }

    func credentials(for id: TranslationProviderID) -> TranslationCredentials? {
        var query = baseQuery(for: id)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return try? JSONDecoder().decode(TranslationCredentials.self, from: data)
    }

    func save(_ credentials: TranslationCredentials, for id: TranslationProviderID) {
        guard let data = try? JSONEncoder().encode(credentials) else { return }

        let query = baseQuery(for: id)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            attributes as CFDictionary
        )

        if updateStatus == errSecItemNotFound {
            var item = query
            attributes.forEach { item[$0.key] = $0.value }
            SecItemAdd(item as CFDictionary, nil)
        }
    }

    func remove(for id: TranslationProviderID) {
        SecItemDelete(baseQuery(for: id) as CFDictionary)
    }

    func hasCredentials(for id: TranslationProviderID) -> Bool {
        credentials(for: id) != nil
    }

    private func baseQuery(for id: TranslationProviderID) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.rawValue
        ]
    }
}

/// Test double that never touches the real Keychain.
@MainActor
final class InMemoryTranslationCredentialStore: TranslationCredentialStoring {
    private var storage: [TranslationProviderID: TranslationCredentials] = [:]

    func credentials(for id: TranslationProviderID) -> TranslationCredentials? {
        storage[id]
    }

    func save(_ credentials: TranslationCredentials, for id: TranslationProviderID) {
        storage[id] = credentials
    }

    func remove(for id: TranslationProviderID) {
        storage.removeValue(forKey: id)
    }

    func hasCredentials(for id: TranslationProviderID) -> Bool {
        storage[id] != nil
    }
}
