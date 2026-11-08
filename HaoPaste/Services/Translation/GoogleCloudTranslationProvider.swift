//
//  GoogleCloudTranslationProvider.swift
//  HaoPaste
//
//  Official Google Cloud Translation Basic API.
//

import Foundation

struct GoogleCloudTranslationProvider: TranslationProvider {
    let id: TranslationProviderID = .googleCloud
    let maxCharactersPerRequest = 30_000

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func translate(_ request: TranslationRequest) async throws -> TranslationResponse {
        let apiKey = request.credentials.trimmed(for: .apiKey)
        guard !apiKey.isEmpty else {
            throw TranslationError.missingCredentials("Google Cloud")
        }

        let text = request.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw TranslationError.emptyText }

        var components = URLComponents(
            string: "https://translation.googleapis.com/language/translate/v2"
        )!
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]

        var body: [String: Any] = [
            "q": text,
            "target": request.target.googleCloudCode,
            "format": "text"
        ]
        if let source = request.source {
            body["source"] = source.googleCloudCode
        }

        var urlRequest = URLRequest(url: components.url!)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 12
        urlRequest.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )
        urlRequest.httpBody = try TranslationHTTP.jsonBody(body)

        let (data, _) = try await TranslationHTTP.data(
            for: urlRequest,
            session: session
        )

        struct Response: Decodable {
            struct DataContainer: Decodable {
                struct Translation: Decodable {
                    let translatedText: String
                    let detectedSourceLanguage: String?
                }

                let translations: [Translation]
            }

            let data: DataContainer
        }

        guard
            let decoded = try? JSONDecoder().decode(Response.self, from: data),
            let translation = decoded.data.translations.first
        else {
            throw TranslationError.invalidResponse
        }

        let translated = TranslationHTTP.decodeHTMLEntities(
            in: translation.translatedText
        )
        guard !translated.isEmpty else {
            throw TranslationError.invalidResponse
        }

        let rawDetected = translation.detectedSourceLanguage
        let detected = rawDetected.flatMap(TranslationLanguage.fromGoogleCode)?.id
            ?? rawDetected

        return TranslationResponse(
            text: translated,
            detectedSourceID: detected
        )
    }
}
