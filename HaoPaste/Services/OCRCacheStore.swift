//
//  OCRCacheStore.swift
//  HaoPaste
//
//  Small local cache for OCR results, keyed by image hash and language.
//

import Foundation

struct OCRCacheEntry: Codable, Equatable {
    let text: String
    let updatedAt: Date
}

@MainActor
protocol OCRCacheStoring: AnyObject {
    func load(key: String) -> String?
    func save(_ text: String, key: String)
    func removeAll()
}

@MainActor
final class OCRDiskCache: OCRCacheStoring {
    private let directoryURL: URL
    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder = JSONDecoder()

    init(
        directoryURL: URL = AppPaths.storageDirectory
            .appendingPathComponent("OCR", isDirectory: true)
    ) {
        self.directoryURL = directoryURL
        self.encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        decoder.dateDecodingStrategy = .millisecondsSince1970
    }

    func load(key: String) -> String? {
        guard let data = try? Data(contentsOf: fileURL(for: key)) else {
            return nil
        }
        return try? decoder.decode(OCRCacheEntry.self, from: data).text
    }

    func save(_ text: String, key: String) {
        do {
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
            let entry = OCRCacheEntry(text: text, updatedAt: .now)
            let data = try encoder.encode(entry)
            try data.write(to: fileURL(for: key), options: .atomic)
        } catch {
            NSLog("HaoPaste: could not save OCR cache — \(error.localizedDescription)")
        }
    }

    func removeAll() {
        try? fileManager.removeItem(at: directoryURL)
    }

    private func fileURL(for key: String) -> URL {
        let safeKey = key.replacingOccurrences(of: "/", with: "_")
        return directoryURL
            .appendingPathComponent(safeKey, isDirectory: false)
            .appendingPathExtension("json")
    }
}

@MainActor
final class InMemoryOCRCache: OCRCacheStoring {
    private var storage: [String: String] = [:]

    func load(key: String) -> String? {
        storage[key]
    }

    func save(_ text: String, key: String) {
        storage[key] = text
    }

    func removeAll() {
        storage.removeAll()
    }
}
