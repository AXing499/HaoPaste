//
//  MergedContentBuilder.swift
//  HaoPaste
//
//  Combines multiple history entries into one pasteboard payload.
//

import Foundation

enum MergedClipboardContent: Equatable {
    case text(String)
    case fileURLs([URL])
    case unsupported
}

enum MergedContentBuilder {
    /// Entries are combined in visible order (top to bottom).
    ///
    /// - Text-like entries are joined with newlines.
    /// - File entries contribute their available paths, or become a multi-file
    ///   pasteboard payload when every selected entry is a file.
    /// - Images cannot currently be merged and make the selection unsupported.
    static func make(from items: [ClipboardItem]) -> MergedClipboardContent {
        guard !items.isEmpty else { return .unsupported }
        guard !items.contains(where: { $0.type == .image }) else {
            return .unsupported
        }

        if items.allSatisfy({ $0.type == .file }) {
            let urls = uniqueFileURLs(from: items)
            return urls.isEmpty ? .unsupported : .fileURLs(urls)
        }

        var parts: [String] = []

        for item in items {
            switch item.type {
            case .text, .code, .url, .colorHex:
                let text = item.content.trimmingCharacters(in: .newlines)
                if !text.isEmpty {
                    parts.append(text)
                }

            case .file:
                parts.append(contentsOf: item.availableFileURLs.map(\.path))

            case .image:
                return .unsupported
            }
        }

        guard !parts.isEmpty else { return .unsupported }
        return .text(parts.joined(separator: "\n"))
    }

    static func uniqueFileURLs(from items: [ClipboardItem]) -> [URL] {
        var seenPaths = Set<String>()
        var urls: [URL] = []

        for item in items where item.type == .file {
            for url in item.availableFileURLs where seenPaths.insert(url.path).inserted {
                urls.append(url)
            }
        }

        return urls
    }
}
