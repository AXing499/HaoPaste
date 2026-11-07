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
    private let historyURL: URL

    private var pendingSave: Task<Void, Never>?

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
        self.historyURL = resolvedBaseURL.appendingPathComponent("history.json", isDirectory: false)

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

            // Image records whose file disappeared are no longer usable.
            return decoded.filter { item in
                guard item.type == .image else { return true }
                guard let fileName = item.imageFileName else { return false }
                return FileManager.default.fileExists(atPath: imageURL(named: fileName).path)
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

    func removeImageAssets(for items: [ClipboardItem]) {
        for item in items where item.type == .image {
            if let fileName = item.imageFileName {
                try? FileManager.default.removeItem(at: imageURL(named: fileName))
            }
            if let thumbnailFileName = item.thumbnailFileName {
                try? FileManager.default.removeItem(at: imageURL(named: thumbnailFileName))
            }
        }
    }

    var imagesDirectoryURL: URL {
        imagesURL
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

    private func imageURL(named fileName: String) -> URL {
        imagesURL.appendingPathComponent(fileName, isDirectory: false)
    }

    private func createDirectoriesIfNeeded() {
        do {
            try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: imagesURL, withIntermediateDirectories: true)
        } catch {
            NSLog("HaoPaste: could not create storage directories — \(error.localizedDescription)")
        }
    }

    private static func defaultBaseURL() -> URL {
        if let override = ProcessInfo.processInfo.environment["HAOPASTE_STORAGE_DIR"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }

        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser

        return applicationSupport.appendingPathComponent("HaoPaste", isDirectory: true)
    }
}
