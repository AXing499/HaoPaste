//
//  ClipboardItem.swift
//  HaoPaste
//
//  The persisted representation of one clipboard entry.
//

import Foundation

// MARK: - Item type

enum ClipboardItemType: String, Codable, CaseIterable, Hashable, Sendable {
    case text
    case image
    case file
    case colorHex
    case url
    case code

    /// Human readable name used in badges and accessibility labels.
    var displayName: String {
        switch self {
        case .text: return "文本"
        case .image: return "图片"
        case .file: return "文件"
        case .colorHex: return "颜色"
        case .url: return "链接"
        case .code: return "代码"
        }
    }

    /// SF Symbols only, as required by the visual language of the app.
    var symbolName: String {
        switch self {
        case .text: return "text.alignleft"
        case .image: return "photo"
        case .file: return "doc"
        case .colorHex: return "paintpalette"
        case .url: return "link"
        case .code: return "chevron.left.forwardslash.chevron.right"
        }
    }
}

// MARK: - Supporting values

struct ImageDimensions: Codable, Hashable, Sendable {
    let width: Int
    let height: Int

    var displayText: String {
        "\(width) × \(height)"
    }
}

struct SourceApplication: Codable, Hashable, Sendable {
    let bundleIdentifier: String?
    let name: String
}

// MARK: - Item

struct ClipboardItem: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var type: ClipboardItemType

    /// Raw text for text-like items, or the full image file name for images.
    var content: String

    /// Plain text used for searching and plain-text output.
    var plainText: String

    var isPinned: Bool
    var createdAt: Date
    var sourceApp: SourceApplication?
    var contentHash: String

    // Image-only metadata. Files live inside Application Support/HaoPaste/Images.
    var imageFileName: String?
    var thumbnailFileName: String?
    var imageDimensions: ImageDimensions?

    /// File URL paths for `.file` items. A single clipboard entry can reference
    /// multiple files selected together in Finder.
    var filePaths: [String]?

    init(
        id: UUID = UUID(),
        type: ClipboardItemType,
        content: String,
        plainText: String,
        isPinned: Bool = false,
        createdAt: Date = .now,
        sourceApp: SourceApplication? = nil,
        contentHash: String,
        imageFileName: String? = nil,
        thumbnailFileName: String? = nil,
        imageDimensions: ImageDimensions? = nil,
        filePaths: [String]? = nil
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.plainText = plainText
        self.isPinned = isPinned
        self.createdAt = createdAt
        self.sourceApp = sourceApp
        self.contentHash = contentHash
        self.imageFileName = imageFileName
        self.thumbnailFileName = thumbnailFileName
        self.imageDimensions = imageDimensions
        self.filePaths = filePaths
    }

    // MARK: Presentation helpers

    /// A single line preview that is safe to render in a compact row.
    var displayTitle: String {
        switch type {
        case .image:
            return "图片"

        case .file:
            let names = (filePaths ?? [])
                .map { URL(fileURLWithPath: $0).lastPathComponent }
                .filter { !$0.isEmpty }
            guard !names.isEmpty else { return "文件" }
            if names.count == 1 { return names[0] }
            if names.count == 2 { return "\(names[0])、\(names[1])" }
            return "\(names[0]) 等 \(names.count) 个文件"

        case .colorHex:
            return content.uppercased()

        case .text, .code, .url:
            let trimmed = plainText.trimmingCharacters(in: .whitespacesAndNewlines)

            // JSON is much more recognisable as a single collapsed line than
            // as a lonely opening brace.
            if type == .code,
               (trimmed.hasPrefix("{") || trimmed.hasPrefix("[")) {
                let prefix = String(trimmed.prefix(260))
                return prefix.replacingOccurrences(
                    of: "\\s+",
                    with: " ",
                    options: .regularExpression
                )
            }

            let firstLine = trimmed
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .first { !$0.isEmpty }

            guard let firstLine, !firstLine.isEmpty else { return "空白内容" }
            return firstLine
        }
    }

    /// Format badge shown on the trailing edge of a row.
    var formatBadge: String {
        switch type {
        case .text: return "文本"
        case .image: return "图片"
        case .file: return "文件"
        case .colorHex: return "颜色"
        case .url: return "链接"
        case .code:
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            let looksLikeJSON = trimmed.hasPrefix("{") || trimmed.hasPrefix("[")
            return looksLikeJSON ? "JSON" : "代码"
        }
    }

    /// Secondary badge, e.g. "42 字符" or "2560 × 1600".
    var detailBadge: String {
        switch type {
        case .image:
            return imageDimensions?.displayText ?? "图片"
        case .file:
            let count = filePaths?.count ?? 0
            guard count > 0 else { return "文件" }
            if !hasAvailableFiles { return "文件已丢失" }
            return count == 1 ? "1 个文件" : "\(count) 个文件"
        case .colorHex:
            return "HEX"
        case .text, .code, .url:
            return "\(plainText.count) 字符"
        }
    }

    var fileCount: Int {
        filePaths?.count ?? 0
    }

    var availableFileURLs: [URL] {
        (filePaths ?? [])
            .map { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    var hasAvailableFiles: Bool {
        !availableFileURLs.isEmpty
    }

    var hasMissingFiles: Bool {
        guard type == .file, let filePaths, !filePaths.isEmpty else { return false }
        return filePaths.contains { !FileManager.default.fileExists(atPath: $0) }
    }

    func matches(_ query: String) -> Bool {
        guard !query.isEmpty else { return true }

        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

        if plainText.range(of: query, options: options) != nil {
            return true
        }

        if let sourceApp, sourceApp.name.range(of: query, options: options) != nil {
            return true
        }

        if type.displayName.range(of: query, options: options) != nil {
            return true
        }

        if formatBadge.range(of: query, options: options) != nil {
            return true
        }

        return false
    }
}

// MARK: - Filters

enum ClipboardFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case text
    case code
    case image
    case file
    case url

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "全部"
        case .text: return "文本"
        case .code: return "代码"
        case .image: return "图片"
        case .file: return "文件"
        case .url: return "链接"
        }
    }

    func matches(_ item: ClipboardItem) -> Bool {
        switch self {
        case .all:
            return true
        case .text:
            // Colors are still text values and stay in the text bucket.
            return item.type == .text || item.type == .colorHex
        case .code:
            return item.type == .code
        case .image:
            return item.type == .image
        case .file:
            return item.type == .file
        case .url:
            return item.type == .url
        }
    }
}

// MARK: - Capture payload

/// The transient result of reading NSPasteboard, before it becomes a persisted item.
struct CapturedClipboard {
    enum Payload {
        case text(String, type: ClipboardItemType)
        case image(Data, dimensions: ImageDimensions)
        case files([String])
    }

    let payload: Payload
    let plainText: String
    let contentHash: String
    let sourceApp: SourceApplication?
}
