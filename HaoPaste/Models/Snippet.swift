//
//  Snippet.swift
//  HaoPaste
//
//  A reusable text fragment managed from Settings.
//

import Foundation

struct Snippet: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    var content: String
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var contentPreview: String {
        content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? "空白片段"
    }

    var characterCount: Int {
        content.count
    }

    func matches(_ query: String) -> Bool {
        guard !query.isEmpty else { return true }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return title.range(of: query, options: options) != nil
            || content.range(of: query, options: options) != nil
    }
}
