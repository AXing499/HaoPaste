//
//  SnippetStore.swift
//  HaoPaste
//
//  JSON persistence for reusable text snippets.
//

import Foundation

@MainActor
final class SnippetStore {
    private let baseURL: URL
    private let fileURL: URL

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }()

    init(baseURL: URL = AppPaths.storageDirectory) {
        self.baseURL = baseURL
        self.fileURL = baseURL.appendingPathComponent("snippets.json", isDirectory: false)

        do {
            try FileManager.default.createDirectory(
                at: baseURL,
                withIntermediateDirectories: true
            )
        } catch {
            NSLog("HaoPaste: could not create snippets directory — \(error.localizedDescription)")
        }
    }

    func load() -> [Snippet] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode([Snippet].self, from: data)
                .filter { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        } catch {
            NSLog("HaoPaste: failed to load snippets — \(error.localizedDescription)")
            return []
        }
    }

    func save(_ snippets: [Snippet]) {
        do {
            let data = try encoder.encode(snippets)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("HaoPaste: failed to save snippets — \(error.localizedDescription)")
        }
    }
}
