//
//  SearchMatcher.swift
//  HaoPaste
//
//  Pinyin-aware, fuzzy and relevance-ranked clipboard search.
//

import Foundation

struct SearchMatcher {
    private struct Fields {
        let title: String
        let text: String
        let source: String
        let type: String
        let format: String
        let titleCompact: String
        let textCompact: String
        let pinyinFull: String
        let pinyinCompact: String
        let pinyinInitials: String
    }

    private struct ScoredItem {
        let item: ClipboardItem
        let score: Int
    }

    func search(
        _ items: [ClipboardItem],
        query: String,
        filter: ClipboardFilter
    ) -> [ClipboardItem] {
        let candidates = items.filter { filter.matches($0) }
        let tokens = Self.tokens(from: query)

        guard !tokens.isEmpty else {
            return candidates.sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned {
                    return lhs.isPinned
                }
                return lhs.createdAt > rhs.createdAt
            }
        }

        let needsPinyin = tokens.contains { token in
            token.unicodeScalars.allSatisfy(\.isASCII)
                && token.contains(where: { $0.isLetter })
        }

        return candidates
            .compactMap { item -> ScoredItem? in
                let fields = makeFields(for: item, includePinyin: needsPinyin)
                guard let score = score(tokens: tokens, in: fields) else {
                    return nil
                }
                return ScoredItem(item: item, score: score)
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }
                if lhs.item.isPinned != rhs.item.isPinned {
                    return lhs.item.isPinned
                }
                return lhs.item.createdAt > rhs.item.createdAt
            }
            .map(\.item)
    }

    private func makeFields(for item: ClipboardItem, includePinyin: Bool) -> Fields {
        let title = Self.normalize(String(item.displayTitle.prefix(300)))
        let text = Self.normalize(String(item.plainText.prefix(1_024)))
        let source = Self.normalize(item.sourceApp?.name ?? "")
        let type = Self.normalize(item.type.displayName)
        let format = Self.normalize(item.formatBadge)

        let pinyinSource = [
            String(item.displayTitle.prefix(300)),
            String(item.plainText.prefix(500)),
            item.sourceApp?.name ?? ""
        ].joined(separator: " ")

        let pinyin = includePinyin
            ? Self.pinyinRepresentations(of: pinyinSource)
            : nil

        return Fields(
            title: title,
            text: text,
            source: source,
            type: type,
            format: format,
            titleCompact: Self.compact(title),
            textCompact: Self.compact(text),
            pinyinFull: pinyin?.full ?? "",
            pinyinCompact: pinyin?.compact ?? "",
            pinyinInitials: pinyin?.initials ?? ""
        )
    }

    private func score(tokens: [String], in fields: Fields) -> Int? {
        var total = 0

        for token in tokens {
            guard let tokenScore = score(token: token, in: fields) else {
                return nil
            }
            total += tokenScore
        }

        return total
    }

    private func score(token: String, in fields: Fields) -> Int? {
        if fields.title == token {
            return 1_000
        }
        if fields.title.hasPrefix(token) {
            return 850
        }
        if fields.title.contains(token) {
            return 750
        }
        if fields.text.hasPrefix(token) {
            return 650
        }
        if fields.text.contains(token) {
            return 550
        }
        if fields.source.contains(token) {
            return 400
        }
        if fields.type.contains(token) || fields.format.contains(token) {
            return 350
        }

        // Pinyin matching lets Latin queries find Chinese clipboard content.
        if fields.pinyinInitials.contains(token) {
            return 500
        }
        if fields.pinyinCompact.contains(token) {
            return 460
        }
        if fields.pinyinFull.contains(token) {
            return 430
        }

        if token.count >= 2, Self.isSubsequence(token, of: fields.titleCompact) {
            return 240
        }
        if token.count >= 3, Self.isSubsequence(token, of: fields.textCompact) {
            return 160
        }
        if token.count >= 3, Self.isSubsequence(token, of: fields.pinyinCompact) {
            return 120
        }

        return nil
    }

    // MARK: - Normalization

    private static func tokens(from query: String) -> [String] {
        normalize(query)
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private static func normalize(_ string: String) -> String {
        string
            .folding(
                options: [.diacriticInsensitive, .widthInsensitive],
                locale: .current
            )
            .lowercased()
    }

    private static func compact(_ string: String) -> String {
        string.unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
    }

    private static func isSubsequence(_ needle: String, of haystack: String) -> Bool {
        guard !needle.isEmpty, needle.count <= haystack.count else {
            return false
        }

        var index = haystack.startIndex

        for character in needle {
            guard let found = haystack[index...].firstIndex(of: character) else {
                return false
            }
            index = haystack.index(after: found)
        }

        return true
    }

    private static func pinyinRepresentations(
        of text: String
    ) -> (full: String, compact: String, initials: String)? {
        guard text.unicodeScalars.contains(where: isCJK) else {
            return nil
        }

        let mutable = NSMutableString(string: String(text.prefix(700)))
        CFStringTransform(
            mutable,
            nil,
            kCFStringTransformToLatin as CFString,
            false
        )
        CFStringTransform(
            mutable,
            nil,
            kCFStringTransformStripCombiningMarks as CFString,
            false
        )

        let full = normalize(String(mutable))
        let words = full
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)

        guard !words.isEmpty else { return nil }

        let initials = words
            .compactMap { $0.first }
            .map(String.init)
            .joined()

        return (full, compact(full), initials)
    }

    private static func isCJK(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF:
            return true
        default:
            return false
        }
    }
}
