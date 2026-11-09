//
//  QuickTranslationSupport.swift
//  HaoPaste
//
//  Pure helpers shared by the panel and the quick translation card.
//

import AppKit
import Foundation

enum AutoTranslationPolicy {
    /// The newest record by copy time. Pinned items sort first in the UI but
    /// must not be mistaken for the latest clipboard entry.
    static func latestItem(in items: [ClipboardItem]) -> ClipboardItem? {
        items.max { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    static func signature(for item: ClipboardItem) -> String {
        "\(item.id.uuidString)-\(item.createdAt.timeIntervalSince1970)"
    }

    static func shouldTranslate(
        item: ClipboardItem,
        targetLanguageID: String,
        lastSignature: String?,
        enabled: Bool
    ) -> Bool {
        guard enabled, item.isTranslatable else { return false }
        guard signature(for: item) != lastSignature else { return false }

        guard let detected = TranslationLanguage.detect(in: item.content) else {
            return false
        }

        if detected.id == targetLanguageID {
            return false
        }

        // Automatic translation should not convert between simplified and
        // traditional Chinese without an explicit request.
        if detected.id.hasPrefix("zh"), targetLanguageID.hasPrefix("zh") {
            return false
        }

        return true
    }
}

enum ClipboardTranslationReader {
    static func text(from pasteboard: NSPasteboard) -> String? {
        guard
            let string = pasteboard.string(forType: .string)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            !string.isEmpty
        else {
            return nil
        }
        return string
    }
}
