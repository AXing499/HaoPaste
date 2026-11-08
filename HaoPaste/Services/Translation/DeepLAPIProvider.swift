//
//  DeepLAPIProvider.swift
//  HaoPaste
//
//  Official DeepL API (Free and Pro).
//

import Foundation

struct DeepLAPIProvider: TranslationProvider {
    let id: TranslationProviderID = .deeplAPI
    let maxCharactersPerRequest = 40_000

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func translate(_ request: TranslationRequest) async throws -> TranslationResponse {
        let apiKey = request.credentials.trimmed(for: .apiKey)
        guard !apiKey.isEmpty else {
            throw TranslationError.missingCredentials("DeepL API")
        }

        let text = request.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw TranslationError.emptyText }

        let endpoint = apiKey.hasSuffix(":fx")
            ? "https://api-free.deepl.com/v2/translate"
            : "https://api.deepl.com/v2/translate"

        var fields: [(String, String)] = [
            ("text", text),
            ("target_lang", request.target.deeplCode),
            ("preserve_formatting", "1")
        ]
        if let source = request.source {
            fields.append(("source_lang", source.deeplCode))
        }

        var urlRequest = URLRequest(url: URL(string: endpoint)!)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 12
        urlRequest.setValue(
            "application/x-www-form-urlencoded; charset=utf-8",
            forHTTPHeaderField: "Content-Type"
        )
        urlRequest.setValue(
            "DeepL-Auth-Key \(apiKey)",
            forHTTPHeaderField: "Authorization"
        )
        urlRequest.httpBody = TranslationHTTP.formBody(fields)

        let (data, _) = try await TranslationHTTP.data(
            for: urlRequest,
            session: session
        )

        struct Response: Decodable {
            struct Translation: Decodable {
                let detected_source_language: String?
                let text: String
            }

            let translations: [Translation]
        }

        guard
            let decoded = try? JSONDecoder().decode(Response.self, from: data),
            let translated = decoded.translations.first?.text,
            !translated.isEmpty
        else {
            throw TranslationError.invalidResponse
        }

        let rawDetected = decoded.translations.first?.detected_source_language
        let detected = rawDetected.flatMap(TranslationLanguage.fromDeepLCode)?.id
            ?? rawDetected

        return TranslationResponse(
            text: translated,
            detectedSourceID: detected
        )
    }
}
