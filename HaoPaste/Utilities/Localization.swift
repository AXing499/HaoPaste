//
//  Localization.swift
//  HaoPaste
//
//  Chinese source strings are the localization keys. The app ships an
//  English and a Simplified Chinese localization; any Chinese system
//  language uses Simplified Chinese and every other language uses English.
//

import Foundation

enum AppLanguage {
    private static let preferred = Locale.preferredLanguages.first?
        .lowercased() ?? "en"

    /// Chinese system languages use Simplified Chinese. Every other
    /// language uses the English localization.
    static let isChinese = preferred.hasPrefix("zh")
    static let code = isChinese ? "zh-Hans" : "en"
    static let locale = Locale(
        identifier: isChinese
            ? "zh-Hans"
            : (preferred.hasPrefix("en") ? preferred : "en-US")
    )
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
