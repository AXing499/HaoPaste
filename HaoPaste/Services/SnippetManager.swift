//
//  SnippetManager.swift
//  HaoPaste
//
//  Observable snippet collection with create / update / delete / merge.
//

import Foundation
import Observation

@MainActor
@Observable
final class SnippetManager {
    struct MergeSummary {
        let added: Int
        let updated: Int
        let skipped: Int
    }

    private(set) var snippets: [Snippet] = []

    @ObservationIgnored private let store: SnippetStore

    init(store: SnippetStore? = nil) {
        self.store = store ?? SnippetStore()
        self.snippets = self.store.load().sorted {
            $0.updatedAt > $1.updatedAt
        }
    }

    @discardableResult
    func create(title: String, content: String) -> Snippet? {
        guard let normalized = normalizedSnippet(title: title, content: content) else {
            return nil
        }

        let snippet = Snippet(
            title: normalized.title,
            content: normalized.content
        )
        snippets.insert(snippet, at: 0)
        persist()
        return snippet
    }

    func update(_ snippet: Snippet, title: String, content: String) {
        guard let normalized = normalizedSnippet(title: title, content: content) else {
            return
        }
        guard let index = snippets.firstIndex(where: { $0.id == snippet.id }) else {
            return
        }

        snippets[index].title = normalized.title
        snippets[index].content = normalized.content
        snippets[index].updatedAt = .now
        snippets.sort { $0.updatedAt > $1.updatedAt }
        persist()
    }

    func delete(_ snippet: Snippet) {
        guard snippets.contains(where: { $0.id == snippet.id }) else { return }
        snippets.removeAll { $0.id == snippet.id }
        persist()
    }

    func snippet(withID id: UUID) -> Snippet? {
        snippets.first { $0.id == id }
    }

    func filtered(query: String) -> [Snippet] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = trimmed.isEmpty
            ? snippets
            : snippets.filter { $0.matches(trimmed) }

        return filtered.sorted { $0.updatedAt > $1.updatedAt }
    }

    func mergeImported(_ imported: [Snippet]) -> MergeSummary {
        var added = 0
        var updated = 0
        var skipped = 0

        for candidate in imported {
            guard
                let normalized = normalizedSnippet(
                    title: candidate.title,
                    content: candidate.content
                )
            else {
                skipped += 1
                continue
            }

            if let index = snippets.firstIndex(where: { $0.id == candidate.id }) {
                if candidate.updatedAt > snippets[index].updatedAt {
                    snippets[index].title = normalized.title
                    snippets[index].content = normalized.content
                    snippets[index].updatedAt = candidate.updatedAt
                    updated += 1
                } else {
                    skipped += 1
                }
                continue
            }

            if snippets.contains(where: {
                $0.title == normalized.title && $0.content == normalized.content
            }) {
                skipped += 1
                continue
            }

            snippets.append(
                Snippet(
                    id: candidate.id,
                    title: normalized.title,
                    content: normalized.content,
                    createdAt: candidate.createdAt,
                    updatedAt: candidate.updatedAt
                )
            )
            added += 1
        }

        if added > 0 || updated > 0 {
            snippets.sort { $0.updatedAt > $1.updatedAt }
            persist()
        }

        return MergeSummary(added: added, updated: updated, skipped: skipped)
    }

    private func normalizedSnippet(
        title: String,
        content: String
    ) -> (title: String, content: String)? {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return nil }

        var trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            trimmedTitle = trimmedContent
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .first { !$0.isEmpty } ?? L("未命名片段")
        }

        return (trimmedTitle, trimmedContent)
    }

    private func persist() {
        store.save(snippets)
    }
}
