//
//  TranslationProviderFactory.swift
//  HaoPaste
//

import Foundation

enum TranslationProviderFactory {
    static func makeDefaultProviders(
        session: URLSession = .shared
    ) -> [any TranslationProvider] {
        [
            GoogleUnofficialProvider(session: session),
            BingUnofficialProvider(session: session),
            DeepLUnofficialProvider(session: session),
            AzureTranslatorProvider(session: session),
            DeepLAPIProvider(session: session),
            BaiduTranslateProvider(session: session),
            GoogleCloudTranslationProvider(session: session)
        ]
    }

    static func makeDictionary(
        providers: [any TranslationProvider]
    ) -> [TranslationProviderID: any TranslationProvider] {
        var result: [TranslationProviderID: any TranslationProvider] = [:]
        for provider in providers {
            result[provider.id] = provider
        }
        return result
    }
}
