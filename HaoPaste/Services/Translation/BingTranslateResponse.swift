//
//  BingTranslateResponse.swift
//  HaoPaste
//
//  Shared response shape for Bing Edge and Azure Translator.
//

import Foundation

struct BingTranslateResponse: Decodable {
    struct DetectedLanguage: Decodable {
        let language: String?
        let score: Double?
    }

    struct Translation: Decodable {
        let text: String
        let to: String?
    }

    let detectedLanguage: DetectedLanguage?
    let translations: [Translation]

    static func parse(_ data: Data) throws -> TranslationResponse {
        let decoder = JSONDecoder()

        // The Edge endpoint returns an array; the Azure API also returns one
        // entry per input text. Accept a single object as a test/mock fallback.
        let decoded: BingTranslateResponse
        if let array = try? decoder.decode([BingTranslateResponse].self, from: data) {
            guard let first = array.first else {
                throw TranslationError.invalidResponse
            }
            decoded = first
        } else if let single = try? decoder.decode(Self.self, from: data) {
            decoded = single
        } else {
            throw TranslationError.invalidResponse
        }

        guard
            let translated = decoded.translations.first?.text,
            !translated.isEmpty
        else {
            throw TranslationError.invalidResponse
        }

        let rawDetected = decoded.detectedLanguage?.language
        let detected = rawDetected.flatMap(TranslationLanguage.fromBingCode)?.id
            ?? rawDetected

        return TranslationResponse(
            text: translated,
            detectedSourceID: detected
        )
    }
}
