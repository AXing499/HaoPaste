//
//  TranslationModels.swift
//  HaoPaste
//
//  Shared types for the pluggable translation engine layer.
//

import Foundation

// MARK: - Provider identity

enum TranslationProviderID: String, CaseIterable, Codable, Identifiable, Sendable {
    case googleUnofficial = "google.unofficial"
    case bingUnofficial = "bing.unofficial"
    case deeplUnofficial = "deepl.unofficial"
    case azure = "azure"
    case deeplAPI = "deepl.api"
    case baidu = "baidu"
    case googleCloud = "google.cloud"

    var id: String { rawValue }

    var descriptor: TranslationProviderDescriptor {
        switch self {
        case .googleUnofficial:
            return TranslationProviderDescriptor(
                id: self,
                name: "Google",
                subtitle: L("非官方接口 · 无需配置 · 可能限流"),
                kind: .unofficial,
                requiredFields: []
            )
        case .bingUnofficial:
            return TranslationProviderDescriptor(
                id: self,
                name: "Bing",
                subtitle: L("非官方接口 · 无需配置 · 可能限流"),
                kind: .unofficial,
                requiredFields: []
            )
        case .deeplUnofficial:
            return TranslationProviderDescriptor(
                id: self,
                name: "DeepL",
                subtitle: L("非官方接口 · 实验性，可能失效"),
                kind: .unofficial,
                requiredFields: []
            )
        case .azure:
            return TranslationProviderDescriptor(
                id: self,
                name: "Azure Translator",
                subtitle: L("官方 API · 订阅密钥 + 区域"),
                kind: .official,
                requiredFields: [.apiKey, .region]
            )
        case .deeplAPI:
            return TranslationProviderDescriptor(
                id: self,
                name: "DeepL API",
                subtitle: L("官方 API · 自动识别 Free / Pro"),
                kind: .official,
                requiredFields: [.apiKey]
            )
        case .baidu:
            return TranslationProviderDescriptor(
                id: self,
                name: L("百度翻译"),
                subtitle: L("官方 API · AppID + 密钥"),
                kind: .official,
                requiredFields: [.appID, .secretKey]
            )
        case .googleCloud:
            return TranslationProviderDescriptor(
                id: self,
                name: "Google Cloud",
                subtitle: L("官方 API · API Key"),
                kind: .official,
                requiredFields: [.apiKey]
            )
        }
    }
}

enum TranslationProviderKind: String, Sendable {
    case unofficial
    case official

    var label: String {
        switch self {
        case .unofficial: return L("非官方")
        case .official: return L("官方")
        }
    }
}

struct TranslationProviderDescriptor: Identifiable, Sendable {
    let id: TranslationProviderID
    let name: String
    let subtitle: String
    let kind: TranslationProviderKind
    let requiredFields: [TranslationCredentialField]

    var requiresConfiguration: Bool {
        !requiredFields.isEmpty
    }

    var badge: String {
        kind.label
    }
}

enum TranslationCredentialField: String, CaseIterable, Sendable {
    case apiKey
    case region
    case appID
    case secretKey

    var title: String {
        switch self {
        case .apiKey: return "API Key"
        case .region: return L("区域（Region）")
        case .appID: return "AppID"
        case .secretKey: return L("密钥（Secret Key）")
        }
    }

    var placeholder: String {
        switch self {
        case .apiKey: return L("粘贴 API Key")
        case .region: return L("例如 eastasia")
        case .appID: return L("百度翻译 AppID")
        case .secretKey: return L("百度翻译密钥")
        }
    }

    var isSecret: Bool {
        switch self {
        case .apiKey, .secretKey: return true
        case .region, .appID: return false
        }
    }
}

// MARK: - Credentials

struct TranslationCredentials: Codable, Equatable, Sendable {
    var apiKey = ""
    var region = ""
    var appID = ""
    var secretKey = ""

    func value(for field: TranslationCredentialField) -> String {
        switch field {
        case .apiKey: return apiKey
        case .region: return region
        case .appID: return appID
        case .secretKey: return secretKey
        }
    }

    mutating func set(_ value: String, for field: TranslationCredentialField) {
        switch field {
        case .apiKey: apiKey = value
        case .region: region = value
        case .appID: appID = value
        case .secretKey: secretKey = value
        }
    }

    func hasValues(for descriptor: TranslationProviderDescriptor) -> Bool {
        descriptor.requiredFields.allSatisfy { field in
            !value(for: field).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    func trimmed(for field: TranslationCredentialField) -> String {
        value(for: field).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Request / response

struct TranslationRequest: Sendable {
    let text: String
    let source: TranslationLanguage?
    let target: TranslationLanguage
    let credentials: TranslationCredentials
}

struct TranslationResponse: Sendable {
    let text: String
    let detectedSourceID: String?
}

// MARK: - Errors

enum TranslationError: LocalizedError, Sendable {
    case emptyText
    case missingCredentials(String)
    case unsupportedLanguage
    case invalidResponse
    case requestFailed(Int, String?)
    case service(String)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .emptyText:
            return L("没有可翻译的内容。")
        case let .missingCredentials(provider):
            return L("请先在设置中配置 %@ 的 API 凭证。", provider)
        case .unsupportedLanguage:
            return L("当前引擎不支持这个语言组合，请更换目标语言或引擎。")
        case .invalidResponse:
            return L("翻译服务返回了无法解析的数据。")
        case let .requestFailed(status, message):
            if let message, !message.isEmpty {
                return L("请求失败（%d）：%@", status, message)
            }
            switch status {
            case 401, 403:
                return L("凭证无效或权限不足（%d）。", status)
            case 429:
                return L("请求过于频繁，请稍后再试（429）。")
            case 500...599:
                return L("翻译服务暂时不可用（%d）。", status)
            default:
                return L("请求失败（%d）。", status)
            }
        case let .service(message):
            return message
        case let .network(message):
            return L("网络请求失败：%@", message)
        }
    }
}

// MARK: - Provider

protocol TranslationProvider: Sendable {
    var id: TranslationProviderID { get }
    var maxCharactersPerRequest: Int { get }

    func translate(_ request: TranslationRequest) async throws -> TranslationResponse
    func testConnection(_ credentials: TranslationCredentials) async throws
}

extension TranslationProvider {
    func testConnection(_ credentials: TranslationCredentials) async throws {
        _ = try await translate(
            TranslationRequest(
                text: "Hello",
                source: .english,
                target: .simplifiedChinese,
                credentials: credentials
            )
        )
    }
}
