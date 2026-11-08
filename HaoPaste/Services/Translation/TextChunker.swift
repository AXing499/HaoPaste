//
//  TextChunker.swift
//  HaoPaste
//
//  Splits long clipboard text into provider-sized translation requests.
//

import Foundation

enum TextChunker {
    static func chunks(of text: String, limit: Int) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        guard limit > 0, trimmed.count > limit else { return [trimmed] }

        let breakCharacters = CharacterSet(charactersIn: ".!?。！？；;")
        var remaining = trimmed
        var result: [String] = []

        while remaining.count > limit {
            let prefix = String(remaining.prefix(limit))
            var splitOffset = prefix.count

            if let range = prefix.range(of: "\n\n", options: .backwards) {
                splitOffset = prefix.distance(
                    from: prefix.startIndex,
                    to: range.upperBound
                )
            } else if let range = prefix.range(of: "\n", options: .backwards) {
                splitOffset = prefix.distance(
                    from: prefix.startIndex,
                    to: range.upperBound
                )
            } else if let range = prefix.rangeOfCharacter(
                from: breakCharacters,
                options: .backwards
            ) {
                splitOffset = prefix.distance(
                    from: prefix.startIndex,
                    to: range.upperBound
                )
            }

            // Avoid tiny chunks when the only break is near the beginning.
            if splitOffset < limit / 3 {
                splitOffset = prefix.count
            }

            let chunk = String(remaining.prefix(splitOffset))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !chunk.isEmpty {
                result.append(chunk)
            }
            remaining = String(remaining.dropFirst(splitOffset))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if !remaining.isEmpty {
            result.append(remaining)
        }

        return result
    }
}
