//
//  ContentClassifier.swift
//  HaoPaste
//
//  Lightweight, deterministic heuristics for turning clipboard text into a type.
//

import Foundation

enum ContentClassifier {
    private static let colorHexRegex = try! NSRegularExpression(
        pattern: "^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$"
    )

    private static let strongCodeMarkers = [
        "func ", "struct ", "extension ", "const ", "def ", "function ",
        "=>", "#include", "#!/", "<?xml", "<!doctype", "<html", "</",
        "public class ", "private func ", "interface "
    ]

    private static let declarationMarkers = [
        "let ", "var ", "class ", "enum ", "return "
    ]

    static func classify(_ text: String) -> ClipboardItemType {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .text }

        if isColorHex(trimmed) {
            return .colorHex
        }

        if isURL(trimmed) {
            return .url
        }

        if isJSON(trimmed) || looksLikeCode(trimmed) {
            return .code
        }

        return .text
    }

    static func isColorHex(_ text: String) -> Bool {
        guard text.hasPrefix("#") else { return false }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return colorHexRegex.firstMatch(in: text, options: [], range: range) != nil
    }

    static func isURL(_ text: String) -> Bool {
        guard text.count <= 4_096, !text.contains(where: \.isWhitespace) else {
            return false
        }

        if text.lowercased().hasPrefix("www.") {
            return URL(string: "https://\(text)")?.host != nil
        }

        guard
            let url = URL(string: text),
            let scheme = url.scheme?.lowercased(),
            ["http", "https", "mailto", "ftp", "tel"].contains(scheme)
        else {
            return false
        }

        switch scheme {
        case "http", "https", "ftp":
            return url.host != nil
        case "mailto", "tel":
            return true
        default:
            return false
        }
    }

    static func isJSON(_ text: String) -> Bool {
        guard text.hasPrefix("{") || text.hasPrefix("[") else { return false }
        guard text.utf8.count <= 2_000_000, let data = text.data(using: .utf8) else {
            return false
        }

        return (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) != nil
    }

    static func looksLikeCode(_ text: String) -> Bool {
        guard text.count > 6 else { return false }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()

        // Anything that clearly looks like a JSON container is code even if it is
        // too large to validate synchronously.
        if (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) ||
            (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) {
            return true
        }

        // Imports and includes are almost always written at the start of a line.
        let firstLines = trimmed.split(separator: "\n", omittingEmptySubsequences: true).prefix(24)
        let hasImportLine = firstLines.contains { line in
            let line = line.trimmingCharacters(in: .whitespaces)
            return line.hasPrefix("import ")
                || (line.hasPrefix("from ") && line.contains(" import "))
                || line.hasPrefix("#include ")
        }

        if hasImportLine {
            return true
        }

        // SQL statements are common clipboard content for developers.
        if trimmed.contains(";"),
           let firstLine = firstLines.first {
            let line = firstLine
                .trimmingCharacters(in: .whitespaces)
                .lowercased()
            let sqlPrefixes = [
                "select ", "insert into ", "update ", "delete from ",
                "create table ", "alter table "
            ]
            if sqlPrefixes.contains(where: { line.hasPrefix($0) }) {
                return true
            }
        }

        let hasStrongMarker = Self.strongCodeMarkers.contains { lowercased.contains($0) }
        if hasStrongMarker {
            return trimmed.contains("\n")
                || trimmed.contains("{")
                || trimmed.contains(";")
                || trimmed.contains(" = ")
                || trimmed.contains("(")
                || trimmed.contains("<")
        }

        // Keywords like "let" appear in normal prose ("let me know"). Only treat
        // them as code when declaration/assignment syntax is also present.
        let hasDeclarationMarker = Self.declarationMarkers.contains { lowercased.contains($0) }
        guard hasDeclarationMarker else { return false }

        return trimmed.contains(" = ")
            || trimmed.contains("=")
            || trimmed.contains(": ")
            || trimmed.contains("{")
            || trimmed.contains(";")
            || trimmed.contains("->")
    }
}
