//
//  BingUnofficialProvider.swift
//  HaoPaste
//
//  Unofficial Edge translator endpoint. No credentials, no guarantee.
//

import Foundation

struct BingUnofficialProvider: TranslationProvider {
    let id: TranslationProviderID = .bingUnofficial
    let maxCharactersPerRequest = 4_500

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func translate(_ request: TranslationRequest) async throws -> TranslationResponse {
        let text = request.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw TranslationError.emptyText }

        var components = URLComponents(
            string: "https://edge.microsoft.com/translate/translatetext"
        )!
        components.queryItems = [
            URLQueryItem(name: "from", value: request.source?.bingCode ?? ""),
            URLQueryItem(name: "to", value: request.target.bingCode)
        ]

        var urlRequest = URLRequest(url: components.url!)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 10
        urlRequest.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )
        urlRequest.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        urlRequest.httpBody = try TranslationHTTP.jsonBody([text])

        let (data, _) = try await TranslationHTTP.data(
            for: urlRequest,
            session: session
        )

        return try BingTranslateResponse.parse(data)
    }
}
