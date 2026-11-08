//
//  GoogleUnofficialProvider.swift
//  HaoPaste
//
//  Unofficial Google web translation endpoint. No credentials, no guarantee.
//

import Foundation

struct GoogleUnofficialProvider: TranslationProvider {
    let id: TranslationProviderID = .googleUnofficial
    let maxCharactersPerRequest = 1_800

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func translate(_ request: TranslationRequest) async throws -> TranslationResponse {
        let text = request.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw TranslationError.emptyText }

        var urlRequest = URLRequest(
            url: URL(string: "https://translate.googleapis.com/translate_a/single")!
        )
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 10
        urlRequest.setValue(
            "application/x-www-form-urlencoded; charset=utf-8",
            forHTTPHeaderField: "Content-Type"
        )
        urlRequest.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        urlRequest.httpBody = TranslationHTTP.formBody([
            ("client", "gtx"),
            ("sl", request.source?.googleCode ?? "auto"),
            ("tl", request.target.googleCode),
            ("dt", "t"),
            ("q", text)
        ])

        let (data, _) = try await TranslationHTTP.data(
            for: urlRequest,
            session: session
        )

        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [Any],
            let segments = root.first as? [Any]
        else {
            throw TranslationError.invalidResponse
        }

        let translated = segments.compactMap { segment -> String? in
            (segment as? [Any])?.first as? String
        }.joined()

        guard !translated.isEmpty else {
            throw TranslationError.invalidResponse
        }

        let rawDetected = root.count > 2 ? root[2] as? String : nil
        let detected = rawDetected.flatMap(TranslationLanguage.fromGoogleCode)?.id
            ?? rawDetected

        return TranslationResponse(
            text: translated,
            detectedSourceID: detected
        )
    }
}
