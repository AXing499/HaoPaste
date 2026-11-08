//
//  TranslationHTTP.swift
//  HaoPaste
//
//  Small shared helpers for the HTTP translation providers.
//

import Foundation

enum TranslationHTTP {
    static func data(
        for request: URLRequest,
        session: URLSession
    ) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            return (data, try validate(data, response))
        } catch let error as TranslationError {
            throw error
        } catch is CancellationError {
            throw TranslationError.service("翻译已取消。")
        } catch let error as URLError {
            if error.code == .cancelled {
                throw TranslationError.service("翻译已取消。")
            }
            throw TranslationError.network(error.localizedDescription)
        } catch {
            throw TranslationError.network(error.localizedDescription)
        }
    }

    static func validate(
        _ data: Data,
        _ response: URLResponse
    ) throws -> HTTPURLResponse {
        guard let http = response as? HTTPURLResponse else {
            throw TranslationError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            throw TranslationError.requestFailed(
                http.statusCode,
                serverMessage(from: data)
            )
        }

        return http
    }

    static func formBody(_ items: [(String, String)]) -> Data {
        var components = URLComponents()
        components.queryItems = items.map { URLQueryItem(name: $0.0, value: $0.1) }
        return Data((components.percentEncodedQuery ?? "").utf8)
    }

    static func jsonBody(_ object: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [])
    }

    static func serverMessage(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) else {
            return plainTextSnippet(from: data)
        }

        if let dictionary = object as? [String: Any] {
            if let error = dictionary["error"] as? [String: Any],
               let message = error["message"] as? String {
                return message
            }
            if let message = dictionary["error_msg"] as? String {
                return message
            }
            if let message = dictionary["message"] as? String {
                return message
            }
            if let message = dictionary["error"] as? String {
                return message
            }
        }

        return nil
    }

    /// Google Cloud returns HTML entities even when text format is requested.
    static func decodeHTMLEntities(in text: String) -> String {
        var result = text
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")

        result = replaceNumericEntities(in: result, pattern: "&#([0-9]+);") {
            UInt32($0).flatMap(UnicodeScalar.init)
        }
        result = replaceNumericEntities(in: result, pattern: "&#x([0-9A-Fa-f]+);") {
            UInt32($0, radix: 16).flatMap(UnicodeScalar.init)
        }

        return result
    }

    private static func replaceNumericEntities(
        in text: String,
        pattern: String,
        scalar: (String) -> UnicodeScalar?
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text
        }

        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)
        guard !matches.isEmpty else { return text }

        var result = text
        for match in matches.reversed() {
            guard
                let fullRange = Range(match.range, in: result),
                let valueRange = Range(match.range(at: 1), in: result),
                let scalar = scalar(String(result[valueRange]))
            else {
                continue
            }
            result.replaceSubrange(fullRange, with: String(Character(scalar)))
        }

        return result
    }

    private static func plainTextSnippet(from data: Data) -> String? {
        guard
            let text = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            !text.isEmpty
        else {
            return nil
        }

        return String(text.prefix(240))
    }
}
