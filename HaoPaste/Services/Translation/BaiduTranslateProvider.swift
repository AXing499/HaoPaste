//
//  BaiduTranslateProvider.swift
//  HaoPaste
//
//  Official Baidu Translate API.
//

import CryptoKit
import Foundation

struct BaiduTranslateProvider: TranslationProvider {
    let id: TranslationProviderID = .baidu
    let maxCharactersPerRequest = 1_800

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func translate(_ request: TranslationRequest) async throws -> TranslationResponse {
        let appID = request.credentials.trimmed(for: .appID)
        let secretKey = request.credentials.trimmed(for: .secretKey)
        guard !appID.isEmpty, !secretKey.isEmpty else {
            throw TranslationError.missingCredentials(L("百度翻译"))
        }

        let text = request.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw TranslationError.emptyText }

        let salt = String(Int.random(in: 100_000...999_999))
        let sign = md5(appID + text + salt + secretKey)

        var urlRequest = URLRequest(
            url: URL(string: "https://fanyi-api.baidu.com/api/trans/vip/translate")!
        )
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 12
        urlRequest.setValue(
            "application/x-www-form-urlencoded; charset=utf-8",
            forHTTPHeaderField: "Content-Type"
        )
        urlRequest.httpBody = TranslationHTTP.formBody([
            ("q", text),
            ("from", request.source?.baiduCode ?? "auto"),
            ("to", request.target.baiduCode),
            ("appid", appID),
            ("salt", salt),
            ("sign", sign)
        ])

        let (data, _) = try await TranslationHTTP.data(
            for: urlRequest,
            session: session
        )

        struct Response: Decodable {
            struct Translation: Decodable {
                let src: String?
                let dst: String
            }

            let from: String?
            let trans_result: [Translation]?
            let error_code: String?
            let error_msg: String?
        }

        guard let decoded = try? JSONDecoder().decode(Response.self, from: data) else {
            throw TranslationError.invalidResponse
        }

        if let errorCode = decoded.error_code, errorCode != "0" {
            let message = decoded.error_msg
                ?? L("错误码 %@", errorCode)
            throw TranslationError.service(
                L("百度翻译：%@", message)
            )
        }

        let translated = (decoded.trans_result ?? [])
            .map(\.dst)
            .joined(separator: "\n")

        guard !translated.isEmpty else {
            throw TranslationError.invalidResponse
        }

        let detected = decoded.from.flatMap(TranslationLanguage.fromBaiduCode)?.id
            ?? decoded.from

        return TranslationResponse(
            text: translated,
            detectedSourceID: detected
        )
    }

    private func md5(_ string: String) -> String {
        Insecure.MD5.hash(data: Data(string.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
