//
//  AzureTranslatorProvider.swift
//  HaoPaste
//
//  Official Azure Translator API.
//

import Foundation

struct AzureTranslatorProvider: TranslationProvider {
    let id: TranslationProviderID = .azure
    let maxCharactersPerRequest = 45_000

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func translate(_ request: TranslationRequest) async throws -> TranslationResponse {
        let apiKey = request.credentials.trimmed(for: .apiKey)
        let region = request.credentials.trimmed(for: .region)
        guard !apiKey.isEmpty, !region.isEmpty else {
            throw TranslationError.missingCredentials("Azure Translator")
        }

        let text = request.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw TranslationError.emptyText }

        var components = URLComponents(
            string: "https://api.cognitive.microsofttranslator.com/translate"
        )!
        var queryItems = [
            URLQueryItem(name: "api-version", value: "3.0"),
            URLQueryItem(name: "to", value: request.target.bingCode)
        ]
        if let source = request.source {
            queryItems.append(URLQueryItem(name: "from", value: source.bingCode))
        }
        components.queryItems = queryItems

        var urlRequest = URLRequest(url: components.url!)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 12
        urlRequest.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )
        urlRequest.setValue(
            apiKey,
            forHTTPHeaderField: "Ocp-Apim-Subscription-Key"
        )
        urlRequest.setValue(
            region,
            forHTTPHeaderField: "Ocp-Apim-Subscription-Region"
        )
        urlRequest.httpBody = try TranslationHTTP.jsonBody([
            ["Text": text]
        ])

        let (data, _) = try await TranslationHTTP.data(
            for: urlRequest,
            session: session
        )

        return try BingTranslateResponse.parse(data)
    }
}
