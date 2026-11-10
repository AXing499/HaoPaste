//
//  TranslationLanguage.swift
//  HaoPaste
//
//  Curated translation languages and provider-specific code mapping.
//

import Foundation
import NaturalLanguage

struct TranslationLanguage: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let googleCode: String
    let bingCode: String
    let deeplCode: String
    let baiduCode: String
    let googleCloudCode: String

    static let simplifiedChinese = TranslationLanguage(
        id: "zh-Hans",
        name: L("中文（简体）"),
        googleCode: "zh-CN",
        bingCode: "zh-Hans",
        deeplCode: "ZH",
        baiduCode: "zh",
        googleCloudCode: "zh-CN"
    )

    static let traditionalChinese = TranslationLanguage(
        id: "zh-Hant",
        name: L("中文（繁体）"),
        googleCode: "zh-TW",
        bingCode: "zh-Hant",
        deeplCode: "ZH-HANT",
        baiduCode: "cht",
        googleCloudCode: "zh-TW"
    )

    static let english = TranslationLanguage(
        id: "en",
        name: L("英语"),
        googleCode: "en",
        bingCode: "en",
        deeplCode: "EN",
        baiduCode: "en",
        googleCloudCode: "en"
    )

    static let all: [TranslationLanguage] = [
        simplifiedChinese,
        traditionalChinese,
        english,
        TranslationLanguage(
            id: "ja", name: L("日语"),
            googleCode: "ja", bingCode: "ja", deeplCode: "JA",
            baiduCode: "jp", googleCloudCode: "ja"
        ),
        TranslationLanguage(
            id: "ko", name: L("韩语"),
            googleCode: "ko", bingCode: "ko", deeplCode: "KO",
            baiduCode: "kor", googleCloudCode: "ko"
        ),
        TranslationLanguage(
            id: "fr", name: L("法语"),
            googleCode: "fr", bingCode: "fr", deeplCode: "FR",
            baiduCode: "fra", googleCloudCode: "fr"
        ),
        TranslationLanguage(
            id: "de", name: L("德语"),
            googleCode: "de", bingCode: "de", deeplCode: "DE",
            baiduCode: "de", googleCloudCode: "de"
        ),
        TranslationLanguage(
            id: "es", name: L("西班牙语"),
            googleCode: "es", bingCode: "es", deeplCode: "ES",
            baiduCode: "spa", googleCloudCode: "es"
        ),
        TranslationLanguage(
            id: "ru", name: L("俄语"),
            googleCode: "ru", bingCode: "ru", deeplCode: "RU",
            baiduCode: "ru", googleCloudCode: "ru"
        ),
        TranslationLanguage(
            id: "pt", name: L("葡萄牙语"),
            googleCode: "pt", bingCode: "pt", deeplCode: "PT",
            baiduCode: "pt", googleCloudCode: "pt"
        ),
        TranslationLanguage(
            id: "it", name: L("意大利语"),
            googleCode: "it", bingCode: "it", deeplCode: "IT",
            baiduCode: "it", googleCloudCode: "it"
        ),
        TranslationLanguage(
            id: "ar", name: L("阿拉伯语"),
            googleCode: "ar", bingCode: "ar", deeplCode: "AR",
            baiduCode: "ara", googleCloudCode: "ar"
        ),
        TranslationLanguage(
            id: "th", name: L("泰语"),
            googleCode: "th", bingCode: "th", deeplCode: "TH",
            baiduCode: "th", googleCloudCode: "th"
        ),
        TranslationLanguage(
            id: "vi", name: L("越南语"),
            googleCode: "vi", bingCode: "vi", deeplCode: "VI",
            baiduCode: "vie", googleCloudCode: "vi"
        ),
        TranslationLanguage(
            id: "id", name: L("印尼语"),
            googleCode: "id", bingCode: "id", deeplCode: "ID",
            baiduCode: "id", googleCloudCode: "id"
        ),
        TranslationLanguage(
            id: "tr", name: L("土耳其语"),
            googleCode: "tr", bingCode: "tr", deeplCode: "TR",
            baiduCode: "tr", googleCloudCode: "tr"
        ),
        TranslationLanguage(
            id: "nl", name: L("荷兰语"),
            googleCode: "nl", bingCode: "nl", deeplCode: "NL",
            baiduCode: "nl", googleCloudCode: "nl"
        ),
        TranslationLanguage(
            id: "pl", name: L("波兰语"),
            googleCode: "pl", bingCode: "pl", deeplCode: "PL",
            baiduCode: "pl", googleCloudCode: "pl"
        ),
        TranslationLanguage(
            id: "uk", name: L("乌克兰语"),
            googleCode: "uk", bingCode: "uk", deeplCode: "UK",
            baiduCode: "uk", googleCloudCode: "uk"
        )
    ]

    static func language(for id: String) -> TranslationLanguage? {
        all.first { $0.id == id }
    }

    static var defaultTarget: TranslationLanguage {
        let language = Locale.current.language
        let code = language.languageCode?.identifier
            ?? Locale.current.identifier.split(separator: "_").first.map(String.init)
            ?? "en"

        if code == "zh" {
            if language.script?.identifier == "Hant"
                || Locale.current.identifier.contains("Hant") {
                return traditionalChinese
            }
            return simplifiedChinese
        }

        if let match = all.first(where: { $0.id == code }) {
            return match
        }

        return english
    }

    /// Lightweight local detection used to label the source and avoid asking a
    /// provider to translate a language into itself.
    static func detect(in text: String) -> TranslationLanguage? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return nil }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(String(trimmed.prefix(5_000)))
        if let identifier = recognizer.dominantLanguage?.rawValue {
            if identifier.hasPrefix("zh") {
                if identifier.lowercased().contains("hant") {
                    return traditionalChinese
                }
                return simplifiedChinese
            }

            if let exact = all.first(where: { $0.id == identifier }) {
                return exact
            }

            if let prefixed = all.first(where: {
                $0.id.hasPrefix(identifier + "-")
            }) {
                return prefixed
            }
        }

        // Short CJK strings are often below the recognizer's confidence
        // threshold. Fall back to script detection so a two-character copy
        // still gets the right default direction.
        return cjkLanguage(in: trimmed)
    }

    private static func cjkLanguage(in text: String) -> TranslationLanguage? {
        var hasHan = false
        var hasKana = false
        var hasHangul = false

        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x3040...0x30FF:
                hasKana = true
            case 0xAC00...0xD7AF:
                hasHangul = true
            case 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF:
                hasHan = true
            default:
                continue
            }
        }

        if hasKana {
            return all.first { $0.id == "ja" }
        }
        if hasHangul {
            return all.first { $0.id == "ko" }
        }
        if hasHan {
            return simplifiedChinese
        }
        return nil
    }

    static func fromGoogleCode(_ code: String) -> TranslationLanguage? {
        switch code {
        case "zh-CN": return simplifiedChinese
        case "zh-TW": return traditionalChinese
        default:
            return all.first { $0.googleCode == code || $0.id == code }
        }
    }

    static func fromBaiduCode(_ code: String) -> TranslationLanguage? {
        all.first { $0.baiduCode == code }
    }

    static func fromBingCode(_ code: String) -> TranslationLanguage? {
        all.first { $0.bingCode == code }
    }

    static func fromDeepLCode(_ code: String) -> TranslationLanguage? {
        all.first {
            $0.deeplCode.caseInsensitiveCompare(code) == .orderedSame
        }
    }
}
