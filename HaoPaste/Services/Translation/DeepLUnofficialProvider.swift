//
//  DeepLUnofficialProvider.swift
//  HaoPaste
//
//  Experimental DeepL web JSON-RPC endpoint. Fragile by nature.
//

import Foundation

struct DeepLUnofficialProvider: TranslationProvider {
    let id: TranslationProviderID = .deeplUnofficial
    let maxCharactersPerRequest = 3_000

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func translate(_ request: TranslationRequest) async throws -> TranslationResponse {
        let text = request.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw TranslationError.emptyText }

        let requestID = Int.random(in: 1_000_000...9_999_999)
        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "LMT_handle_texts",
            "params": [
                "texts": [
                    ["text": text, "requestAlternatives": 0]
                ],
                "splitting": "newlines",
                "lang": [
                    "source_lang_user_selected": "auto",
                    "target_lang": request.target.deeplCode
                ],
                "timestamp": Int(Date().timeIntervalSince1970 * 1_000),
                "commonJobParams": [
                    "wasSpoken": false,
                    "transcribeAS": ""
                ]
            ],
            "id": requestID
        ]

        var urlRequest = URLRequest(
            url: URL(string: "https://www2.deepl.com/jsonrpc")!
        )
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 10
        urlRequest.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )
        urlRequest.setValue("*/*", forHTTPHeaderField: "Accept")
        urlRequest.setValue("https://www.deepl.com", forHTTPHeaderField: "Origin")
        urlRequest.setValue(
            "https://www.deepl.com/translator",
            forHTTPHeaderField: "Referer"
        )
        urlRequest.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        urlRequest.httpBody = try TranslationHTTP.jsonBody(payload)

        let (data, _) = try await TranslationHTTP.data(
            for: urlRequest,
            session: session
        )

        struct Response: Decodable {
            struct Result: Decodable {
                struct Text: Decodable {
                    let text: String
                }

                let texts: [Text]
            }

            let result: Result
        }

        guard
            let decoded = try? JSONDecoder().decode(Response.self, from: data),
            let translated = decoded.result.texts.first?.text,
            !translated.isEmpty
        else {
            throw TranslationError.invalidResponse
        }

        if translated.contains("older version of DeepL")
            || translated.contains("旧版本")
            || translated.contains("ältere Version") {
            throw TranslationError.service(
                "DeepL 非官方接口要求更新客户端，当前不可用；请在设置中改用 DeepL API。"
            )
        }

        return TranslationResponse(text: translated, detectedSourceID: nil)
    }
}
