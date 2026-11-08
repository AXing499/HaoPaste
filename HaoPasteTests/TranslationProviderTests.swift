//
//  TranslationProviderTests.swift
//  HaoPasteTests
//

import Foundation
import XCTest
@testable import HaoPaste

final class TranslationProviderTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testGoogleUnofficialRequestAndResponse() async throws {
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.host, "translate.googleapis.com")
            XCTAssertEqual(request.httpMethod, "POST")

            let fields = formFields(request)
            XCTAssertEqual(fields["q"], "Hello")
            XCTAssertEqual(fields["sl"], "auto")
            XCTAssertEqual(fields["tl"], "zh-CN")

            let json: [Any] = [
                [["你好", "Hello", NSNull(), NSNull(), 10]],
                NSNull(),
                "en"
            ]
            return (
                mockResponse(for: request),
                try JSONSerialization.data(withJSONObject: json)
            )
        }

        let provider = GoogleUnofficialProvider(session: makeMockURLSession())
        let response = try await provider.translate(
            TranslationRequest(
                text: "Hello",
                source: nil,
                target: .simplifiedChinese,
                credentials: TranslationCredentials()
            )
        )

        XCTAssertEqual(response.text, "你好")
        XCTAssertEqual(response.detectedSourceID, "en")
    }

    func testBingUnofficialUsesNewEndpoint() async throws {
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.host, "edge.microsoft.com")
            XCTAssertEqual(request.url?.path, "/translate/translatetext")

            let components = URLComponents(
                url: request.url!,
                resolvingAgainstBaseURL: false
            )
            let query = Dictionary(uniqueKeysWithValues: (components?.queryItems ?? []).map {
                ($0.name, $0.value ?? "")
            })
            XCTAssertEqual(query["to"], "zh-Hans")

            let body = try JSONSerialization.jsonObject(
                with: requestBodyData(request)!
            ) as? [String]
            XCTAssertEqual(body, ["Hello"])

            let json: [String: Any] = [
                "detectedLanguage": ["language": "en", "score": 1.0],
                "translations": [["text": "你好", "to": "zh-Hans"]]
            ]
            return (
                mockResponse(for: request),
                try JSONSerialization.data(withJSONObject: json)
            )
        }

        let provider = BingUnofficialProvider(session: makeMockURLSession())
        let response = try await provider.translate(
            TranslationRequest(
                text: "Hello",
                source: nil,
                target: .simplifiedChinese,
                credentials: TranslationCredentials()
            )
        )

        XCTAssertEqual(response.text, "你好")
        XCTAssertEqual(response.detectedSourceID, "en")
    }

    func testAzureTranslatorSendsCredentialsAndParsesResponse() async throws {
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.host, "api.cognitive.microsofttranslator.com")
            XCTAssertEqual(
                request.value(forHTTPHeaderField: "Ocp-Apim-Subscription-Key"),
                "azure-key"
            )
            XCTAssertEqual(
                request.value(forHTTPHeaderField: "Ocp-Apim-Subscription-Region"),
                "eastasia"
            )

            let json: [String: Any] = [
                "detectedLanguage": ["language": "en", "score": 0.98],
                "translations": [["text": "你好", "to": "zh-Hans"]]
            ]
            return (
                mockResponse(for: request),
                try JSONSerialization.data(withJSONObject: json)
            )
        }

        let credentials = TranslationCredentials(
            apiKey: "azure-key",
            region: "eastasia"
        )
        let provider = AzureTranslatorProvider(session: makeMockURLSession())
        let response = try await provider.translate(
            TranslationRequest(
                text: "Hello",
                source: nil,
                target: .simplifiedChinese,
                credentials: credentials
            )
        )

        XCTAssertEqual(response.text, "你好")
        XCTAssertEqual(response.detectedSourceID, "en")
    }

    func testDeepLAPIChoosesFreeEndpointForFxKey() async throws {
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.host, "api-free.deepl.com")
            XCTAssertEqual(
                request.value(forHTTPHeaderField: "Authorization"),
                "DeepL-Auth-Key test-key:fx"
            )

            let fields = formFields(request)
            XCTAssertEqual(fields["text"], "Hello")
            XCTAssertEqual(fields["target_lang"], "ZH")

            let json: [String: Any] = [
                "translations": [[
                    "detected_source_language": "EN",
                    "text": "你好"
                ]]
            ]
            return (
                mockResponse(for: request),
                try JSONSerialization.data(withJSONObject: json)
            )
        }

        let credentials = TranslationCredentials(apiKey: "test-key:fx")
        let provider = DeepLAPIProvider(session: makeMockURLSession())
        let response = try await provider.translate(
            TranslationRequest(
                text: "Hello",
                source: nil,
                target: .simplifiedChinese,
                credentials: credentials
            )
        )

        XCTAssertEqual(response.text, "你好")
        XCTAssertEqual(response.detectedSourceID, "en")
    }

    func testDeepLUnofficialParsesJSONRPCResponse() async throws {
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.host, "www2.deepl.com")
            XCTAssertEqual(request.httpMethod, "POST")

            let body = try JSONSerialization.jsonObject(
                with: requestBodyData(request)!
            ) as? [String: Any]
            XCTAssertEqual(body?["method"] as? String, "LMT_handle_texts")
            let params = body?["params"] as? [String: Any]
            let lang = params?["lang"] as? [String: String]
            XCTAssertEqual(lang?["target_lang"], "ZH")

            let json: [String: Any] = [
                "jsonrpc": "2.0",
                "result": ["texts": [["text": "你好"]]],
                "id": 1
            ]
            return (
                mockResponse(for: request),
                try JSONSerialization.data(withJSONObject: json)
            )
        }

        let provider = DeepLUnofficialProvider(session: makeMockURLSession())
        let response = try await provider.translate(
            TranslationRequest(
                text: "Hello",
                source: nil,
                target: .simplifiedChinese,
                credentials: TranslationCredentials()
            )
        )

        XCTAssertEqual(response.text, "你好")
    }

    func testBaiduSignsRequestAndJoinsLines() async throws {
        MockURLProtocol.handler = { request in
            let fields = formFields(request)
            XCTAssertEqual(fields["appid"], "baidu-app")
            XCTAssertEqual(fields["from"], "auto")
            XCTAssertEqual(fields["to"], "zh")
            XCTAssertEqual(fields["q"], "Hello")
            XCTAssertEqual(fields["sign"]?.count, 32)

            let json: [String: Any] = [
                "from": "en",
                "to": "zh",
                "trans_result": [
                    ["src": "Hello", "dst": "你好"],
                    ["src": "world", "dst": "世界"]
                ]
            ]
            return (
                mockResponse(for: request),
                try JSONSerialization.data(withJSONObject: json)
            )
        }

        let credentials = TranslationCredentials(
            appID: "baidu-app",
            secretKey: "baidu-secret"
        )
        let provider = BaiduTranslateProvider(session: makeMockURLSession())
        let response = try await provider.translate(
            TranslationRequest(
                text: "Hello",
                source: nil,
                target: .simplifiedChinese,
                credentials: credentials
            )
        )

        XCTAssertEqual(response.text, "你好\n世界")
        XCTAssertEqual(response.detectedSourceID, "en")
    }

    func testGoogleCloudDecodesHTMLAndDetectedLanguage() async throws {
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.host, "translation.googleapis.com")
            let json: [String: Any] = [
                "data": [
                    "translations": [[
                        "translatedText": "你好 &amp; 世界",
                        "detectedSourceLanguage": "en"
                    ]]
                ]
            ]
            return (
                mockResponse(for: request),
                try JSONSerialization.data(withJSONObject: json)
            )
        }

        let credentials = TranslationCredentials(apiKey: "google-key")
        let provider = GoogleCloudTranslationProvider(session: makeMockURLSession())
        let response = try await provider.translate(
            TranslationRequest(
                text: "Hello & world",
                source: nil,
                target: .simplifiedChinese,
                credentials: credentials
            )
        )

        XCTAssertEqual(response.text, "你好 & 世界")
        XCTAssertEqual(response.detectedSourceID, "en")
    }
}
