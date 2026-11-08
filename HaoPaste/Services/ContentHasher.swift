//
//  ContentHasher.swift
//  HaoPaste
//
//  Stable fingerprints used for de-duplication.
//

import CryptoKit
import Foundation

enum ContentHasher {
    static func text(_ text: String, type: ClipboardItemType) -> String {
        var hasher = SHA256()
        hasher.update(data: Data(type.rawValue.utf8))
        hasher.update(data: Data(text.utf8))
        return hexDigest(hasher)
    }

    static func imageData(_ data: Data) -> String {
        var hasher = SHA256()
        hasher.update(data: Data(ClipboardItemType.image.rawValue.utf8))
        hasher.update(data: data)
        return hexDigest(hasher)
    }

    static func files(_ paths: [String]) -> String {
        var hasher = SHA256()
        hasher.update(data: Data(ClipboardItemType.file.rawValue.utf8))
        for path in paths.map({ URL(fileURLWithPath: $0).standardizedFileURL.path }).sorted() {
            hasher.update(data: Data(path.utf8))
        }
        return hexDigest(hasher)
    }

    private static func hexDigest(_ hasher: SHA256) -> String {
        hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
