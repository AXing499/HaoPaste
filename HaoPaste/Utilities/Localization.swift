//
//  Localization.swift
//  HaoPaste
//
//  Chinese source strings are the localization keys. The app ships an
//  English and a Simplified Chinese localization. The default follows the
//  system language; Settings can force either language explicitly.
//

import Foundation

enum AppLanguagePreference: String, CaseIterable, Identifiable, Codable, Sendable {
    case system
    case simplifiedChinese
    case english

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return L("跟随系统")
        case .simplifiedChinese: return "简体中文"
        case .english: return "English"
        }
    }
}

enum AppLanguage {
    static let preferenceKey = "settings.appLanguage"

    private static let systemLanguage = Locale.preferredLanguages.first?
        .lowercased() ?? "en"

    /// The preference captured at launch. Changing the setting takes effect
    /// after the app restarts, so the running process stays on this value.
    static let launchPreference = storedPreference()

    /// Chinese system languages use Simplified Chinese. Every other
    /// language uses the English localization.
    static func resolvedCode(
        for preference: AppLanguagePreference
    ) -> String {
        switch preference {
        case .english:
            return "en"
        case .simplifiedChinese:
            return "zh-Hans"
        case .system:
            return systemLanguage.hasPrefix("zh") ? "zh-Hans" : "en"
        }
    }

    static let code = resolvedCode(for: launchPreference)
    static let isChinese = code == "zh-Hans"
    static let locale: Locale = {
        if isChinese {
            return Locale(identifier: "zh-Hans")
        }
        if launchPreference == .system, systemLanguage.hasPrefix("en") {
            return Locale(identifier: systemLanguage)
        }
        return Locale(identifier: "en-US")
    }()

    private static func storedPreference() -> AppLanguagePreference {
        UserDefaults.standard
            .string(forKey: preferenceKey)
            .flatMap(AppLanguagePreference.init(rawValue:))
            ?? .system
    }
}

private let localizedBundle: Bundle = {
    let language = AppLanguage.code

    guard
        let path = Bundle.main.path(forResource: language, ofType: "lproj"),
        let bundle = Bundle(path: path)
    else {
        return .main
    }

    return bundle
}()

func L(_ key: String) -> String {
    localizedBundle.localizedString(forKey: key, value: key, table: nil)
}

func L(_ key: String, _ arguments: CVarArg...) -> String {
    String(
        format: localizedBundle.localizedString(
            forKey: key,
            value: key,
            table: nil
        ),
        locale: AppLanguage.locale,
        arguments: arguments
    )
}
