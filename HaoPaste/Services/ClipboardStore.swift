//
//  ClipboardStore.swift
//  HaoPaste
//
//  Lightweight JSON persistence plus image asset management.
//

import AppKit
import Foundation

@MainActor
final class ClipboardStore {
    enum StoreError: LocalizedError {
        case invalidImage
        case couldNotEncode

        var errorDescription: String? {
            switch self {
            case .invalidImage:
                return "无法读取这张图片。"
            case .couldNotEncode:
                return "无法编码剪贴板数据。"
            }
        }
    }

    struct StoredImage {
        let fileName: String
        let thumbnailFileName: String
        let dimensions: ImageDimensions
    }

    private let baseURL: URL
    private let imagesURL: URL
    private let richTextDirectoryURL: URL
    private let historyURL: URL
    private let trashURL: URL

    private var pendingSave: Task<Void, Never>?
    private var pendingTrashSave: Task<Void, Never>?

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

    init(baseURL: URL? = nil) {
        let resolvedBaseURL = baseURL ?? Self.defaultBaseURL()
        self.baseURL = resolvedBaseURL
        self.imagesURL = resolvedBaseURL.appendingPathComponent("Images", isDirectory: true)
        self.richTextDirectoryURL = resolvedBaseURL.appendingPathComponent("RichText", isDirectory: true)
        self.historyURL = resolvedBaseURL.appendingPathComponent("history.json", isDirectory: false)
        self.trashURL = resolvedBaseURL.appendingPathComponent("trash.json", isDirectory: false)

        createDirectoriesIfNeeded()
    }

    // MARK: - Loading and saving

    func loadItems() -> [ClipboardItem] {
        guard FileManager.default.fileExists(atPath: historyURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: historyURL)
            let decoded = try decoder.decode([ClipboardItem].self, from: data)

            // Drop image records whose file disappeared and degrade rich text
            // records to plain text if their cached representation is missing.
            return decoded.compactMap { decodedItem in
                var item = decodedItem

                if item.type == .image {
                    guard
                        let fileName = item.imageFileName,
                        FileManager.default.fileExists(atPath: imageURL(named: fileName).path)
                    else {
                        return nil
                    }
                }

                if let richTextFileName = item.richTextFileName,
                   !FileManager.default.fileExists(
                       atPath: richTextFileURL(named: richTextFileName).path
                   ) {
                    item.richTextFileName = nil
                }

                return item
            }
        } catch {
            NSLog("HaoPaste: failed to load history — \(error.localizedDescription)")
            return []
        }
    }

    /// Debounced save so fast successive clipboard changes only write once.
    func scheduleSave(_ items: [ClipboardItem]) {
        pendingSave?.cancel()
        pendingSave = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled, let self else { return }
            self.write(items)
        }
    }

    func saveNow(_ items: [ClipboardItem]) {
        pendingSave?.cancel()
        pendingSave = nil
        write(items)
    }

    // MARK: - Recently deleted

    func loadTrash() -> [TrashedClipboardItem] {
        guard FileManager.default.fileExists(atPath: trashURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: trashURL)
            let decoded = try decoder.decode([TrashedClipboardItem].self, from: data)

            return decoded.compactMap { entry in
                var item = entry.item

                if item.type == .image {
                    guard
                        let fileName = item.imageFileName,
                        FileManager.default.fileExists(atPath: imageURL(named: fileName).path)
                    else {
                        return nil
                    }
                }

                if let richTextFileName = item.richTextFileName,
                   !FileManager.default.fileExists(
                       atPath: richTextFileURL(named: richTextFileName).path
                   ) {
                    item.richTextFileName = nil
                }

                return TrashedClipboardItem(
                    item: item,
                    deletedAt: entry.deletedAt
                )
            }
        } catch {
            NSLog("HaoPaste: failed to load trash — \(error.localizedDescription)")
            return []
        }
    }

    func scheduleSaveTrash(_ items: [TrashedClipboardItem]) {
        pendingTrashSave?.cancel()
        pendingTrashSave = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled, let self else { return }
            self.writeTrash(items)
        }
    }

    func saveTrashNow(_ items: [TrashedClipboardItem]) {
        pendingTrashSave?.cancel()
        pendingTrashSave = nil
        writeTrash(items)
    }

    // MARK: - Image assets

    func saveImage(data: Data, id: UUID) throws -> StoredImage {
        guard let prepared = ImageProcessor.prepare(from: data) else {
            throw StoreError.invalidImage
        }

        let fileName = "\(id.uuidString).png"
        let thumbnailFileName = "\(id.uuidString)-thumb.png"
        let fullURL = imageURL(named: fileName)
        let thumbnailURL = imageURL(named: thumbnailFileName)

        do {
            try prepared.fullData.write(to: fullURL, options: .atomic)
            try prepared.thumbnailData.write(to: thumbnailURL, options: .atomic)
        } catch {
            try? FileManager.default.removeItem(at: fullURL)
            try? FileManager.default.removeItem(at: thumbnailURL)
            throw error
        }

        return StoredImage(
            fileName: fileName,
            thumbnailFileName: thumbnailFileName,
            dimensions: prepared.dimensions
        )
    }

    func imageURL(for item: ClipboardItem) -> URL? {
        guard let fileName = item.imageFileName else { return nil }
        return imageURL(named: fileName)
    }

    func thumbnailURL(for item: ClipboardItem) -> URL? {
        guard let fileName = item.thumbnailFileName else { return nil }
        return imageURL(named: fileName)
    }

    func removeAssets(for items: [ClipboardItem]) {
        removeImageAssets(for: items)

        for item in items {
            guard let richTextFileName = item.richTextFileName else { continue }
            try? FileManager.default.removeItem(
                at: richTextFileURL(named: richTextFileName)
            )
        }
    }

    private func removeImageAssets(for items: [ClipboardItem]) {
        for item in items where item.type == .image {
            if let fileName = item.imageFileName {
                try? FileManager.default.removeItem(at: imageURL(named: fileName))
            }
            if let thumbnailFileName = item.thumbnailFileName {
                try? FileManager.default.removeItem(at: imageURL(named: thumbnailFileName))
            }
        }
    }

    // MARK: - Rich text assets

    func saveRichText(_ payload: RichTextPayload, id: UUID) throws -> String {
        let fileName = "\(id.uuidString).json"
        let data = try JSONEncoder().encode(payload)
        try data.write(
            to: richTextFileURL(named: fileName),
            options: .atomic
        )
        return fileName
    }

    func richTextURL(for item: ClipboardItem) -> URL? {
        guard let fileName = item.richTextFileName else { return nil }
        return richTextFileURL(named: fileName)
    }

    func loadRichText(for item: ClipboardItem) -> RichTextPayload? {
        guard let url = richTextURL(for: item) else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(RichTextPayload.self, from: data)
    }

    func importRichTextFile(
        for item: ClipboardItem,
        from directory: URL
    ) throws -> String? {
        guard let sourceFileName = item.richTextFileName else { return nil }
        let sourceName = URL(fileURLWithPath: sourceFileName).lastPathComponent
        let sourceURL = directory.appendingPathComponent(sourceName, isDirectory: false)
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            return nil
        }

        // Validate before copying so malformed backups cannot poison the cache.
        let data = try Data(contentsOf: sourceURL)
        _ = try JSONDecoder().decode(RichTextPayload.self, from: data)

        let newFileName = "\(UUID().uuidString).json"
        try data.write(
            to: richTextFileURL(named: newFileName),
            options: .atomic
        )
        return newFileName
    }

    var richTextAssetsDirectoryURL: URL {
        richTextDirectoryURL
    }

    /// Copies an image item from an imported archive into the local image cache,
    /// giving it a fresh file identity so imports can never overwrite existing assets.
    func importImageItem(
        _ item: ClipboardItem,
        fromImagesDirectory sourceDirectory: URL
    ) throws -> ClipboardItem? {
        guard item.type == .image, let sourceFileName = item.imageFileName else {
            return nil
        }

        let sourceName = URL(fileURLWithPath: sourceFileName).lastPathComponent
        let sourceURL = sourceDirectory.appendingPathComponent(sourceName, isDirectory: false)
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            return nil
        }

        let newID = UUID()
        let newFileName = "\(newID.uuidString).png"
        let newThumbnailName = "\(newID.uuidString)-thumb.png"
        let fullURL = imageURL(named: newFileName)
        let thumbnailURL = imageURL(named: newThumbnailName)

        do {
            try FileManager.default.copyItem(at: sourceURL, to: fullURL)

            let fullData = try Data(contentsOf: fullURL)
            guard let actualDimensions = ImageProcessor.dimensions(of: fullData) else {
                try? FileManager.default.removeItem(at: fullURL)
                return nil
            }

            var thumbnailAvailable = false

            if let sourceThumbnailName = item.thumbnailFileName {
                let sourceThumbnail = sourceDirectory.appendingPathComponent(
                    URL(fileURLWithPath: sourceThumbnailName).lastPathComponent,
                    isDirectory: false
                )
                if FileManager.default.fileExists(atPath: sourceThumbnail.path) {
                    do {
                        try FileManager.default.copyItem(at: sourceThumbnail, to: thumbnailURL)
                        thumbnailAvailable = true
                    } catch {
                        thumbnailAvailable = false
                    }
                }
            }

            if !thumbnailAvailable, let prepared = ImageProcessor.prepare(from: fullData) {
                try? prepared.thumbnailData.write(to: thumbnailURL, options: .atomic)
                thumbnailAvailable = FileManager.default.fileExists(atPath: thumbnailURL.path)
            }

            let dimensions = item.imageDimensions ?? actualDimensions
            return ClipboardItem(
                id: newID,
                type: .image,
                content: newFileName,
                plainText: item.plainText.isEmpty ? "图片 \(dimensions.displayText)" : item.plainText,
                isPinned: item.isPinned,
                createdAt: item.createdAt,
                sourceApp: item.sourceApp,
                contentHash: item.contentHash,
                imageFileName: newFileName,
                thumbnailFileName: thumbnailAvailable ? newThumbnailName : nil,
                imageDimensions: dimensions
            )
        } catch {
            try? FileManager.default.removeItem(at: fullURL)
            try? FileManager.default.removeItem(at: thumbnailURL)
            throw error
        }
    }

    var imagesDirectoryURL: URL {
        imagesURL
    }

    var baseDirectoryURL: URL {
        baseURL
    }

    // MARK: - Private

    private func write(_ items: [ClipboardItem]) {
        do {
            let data = try encoder.encode(items)
            try data.write(to: historyURL, options: .atomic)
        } catch {
            NSLog("HaoPaste: failed to save history — \(error.localizedDescription)")
        }
    }

    private func writeTrash(_ items: [TrashedClipboardItem]) {
        do {
            let data = try encoder.encode(items)
            try data.write(to: trashURL, options: .atomic)
        } catch {
            NSLog("HaoPaste: failed to save trash — \(error.localizedDescription)")
        }
    }

    private func imageURL(named fileName: String) -> URL {
        imagesURL.appendingPathComponent(fileName, isDirectory: false)
    }

    private func richTextFileURL(named fileName: String) -> URL {
        richTextDirectoryURL.appendingPathComponent(fileName, isDirectory: false)
    }

    private func createDirectoriesIfNeeded() {
        do {
            try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: imagesURL, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: richTextDirectoryURL, withIntermediateDirectories: true)
        } catch {
            NSLog("HaoPaste: could not create storage directories — \(error.localizedDescription)")
        }
    }

    private static func defaultBaseURL() -> URL {
        AppPaths.storageDirectory
    }
}
