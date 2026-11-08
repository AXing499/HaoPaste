//
//  HistoryArchiveService.swift
//  HaoPaste
//
//  Versioned .zip archive export/import for history + image assets.
//

import AppKit
import Foundation

@MainActor
final class HistoryArchiveService {
    enum ArchiveError: LocalizedError {
        case temporaryDirectory
        case compressionFailed(String)
        case extractionFailed(String)
        case missingHistory
        case unsupportedVersion(Int)
        case writeFailed(String)

        var errorDescription: String? {
            switch self {
            case .temporaryDirectory:
                return "无法创建临时目录。"
            case let .compressionFailed(message):
                return "导出压缩失败：\(message)"
            case let .extractionFailed(message):
                return "无法解压备份文件：\(message)"
            case .missingHistory:
                return "备份文件中没有找到 history.json。"
            case let .unsupportedVersion(version):
                return "备份格式版本 \(version) 高于当前应用支持的版本。"
            case let .writeFailed(message):
                return "写入备份失败：\(message)"
            }
        }
    }

    struct Manifest: Codable {
        let schemaVersion: Int
        let appVersion: String
        let exportedAt: Date
        let itemCount: Int
        let imageCount: Int
        let snippetCount: Int?
    }

    struct ExportSummary {
        let itemCount: Int
        let imageCount: Int
        let snippetCount: Int
    }

    struct ImportSummary {
        let importedCount: Int
        let mergedPinnedCount: Int
        let skippedCount: Int
        let trimmedCount: Int
        let snippets: [Snippet]
    }

    struct UnpackedArchive {
        let items: [ClipboardItem]
        let snippets: [Snippet]
        let imagesDirectory: URL?
        let manifest: Manifest?
        let temporaryDirectory: URL
    }

    private let supportedSchemaVersion = 2
    private let store: ClipboardStore
    private let fileManager = FileManager.default

    init(store: ClipboardStore) {
        self.store = store
    }

    // MARK: - Export

    func export(
        items: [ClipboardItem],
        snippets: [Snippet],
        to destination: URL
    ) throws -> ExportSummary {
        let temporaryDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("HaoPasteExport-\(UUID().uuidString)", isDirectory: true)
        let payloadDirectory = temporaryDirectory
            .appendingPathComponent("HaoPasteBackup", isDirectory: true)
        let imagesDirectory = payloadDirectory
            .appendingPathComponent("Images", isDirectory: true)

        do {
            try fileManager.createDirectory(
                at: imagesDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            throw ArchiveError.temporaryDirectory
        }

        defer {
            try? fileManager.removeItem(at: temporaryDirectory)
        }

        var imageCount = 0

        do {
            for item in items where item.type == .image {
                guard
                    let sourceURL = store.imageURL(for: item),
                    fileManager.fileExists(atPath: sourceURL.path)
                else {
                    continue
                }

                let fileName = (item.imageFileName as NSString?)?.lastPathComponent
                    ?? sourceURL.lastPathComponent
                try fileManager.copyItem(
                    at: sourceURL,
                    to: imagesDirectory.appendingPathComponent(fileName)
                )

                if
                    let thumbnailURL = store.thumbnailURL(for: item),
                    fileManager.fileExists(atPath: thumbnailURL.path)
                {
                    let thumbnailName = (item.thumbnailFileName as NSString?)?.lastPathComponent
                        ?? thumbnailURL.lastPathComponent
                    try fileManager.copyItem(
                        at: thumbnailURL,
                        to: imagesDirectory.appendingPathComponent(thumbnailName)
                    )
                }

                imageCount += 1
            }

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .millisecondsSince1970
            encoder.outputFormatting = [.sortedKeys]

            let historyData = try encoder.encode(items)
            try historyData.write(
                to: payloadDirectory.appendingPathComponent("history.json"),
                options: .atomic
            )

            let snippetsData = try encoder.encode(snippets)
            try snippetsData.write(
                to: payloadDirectory.appendingPathComponent("snippets.json"),
                options: .atomic
            )

            let manifest = Manifest(
                schemaVersion: supportedSchemaVersion,
                appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                    ?? "unknown",
                exportedAt: .now,
                itemCount: items.count,
                imageCount: imageCount,
                snippetCount: snippets.count
            )

            let manifestEncoder = JSONEncoder()
            manifestEncoder.dateEncodingStrategy = .iso8601
            manifestEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try manifestEncoder.encode(manifest).write(
                to: payloadDirectory.appendingPathComponent("manifest.json"),
                options: .atomic
            )

            try? fileManager.removeItem(at: destination)
            try runDitto([
                "-c", "-k", "--keepParent",
                payloadDirectory.path,
                destination.path
            ], failure: ArchiveError.compressionFailed)
        } catch let error as ArchiveError {
            try? fileManager.removeItem(at: destination)
            throw error
        } catch {
            try? fileManager.removeItem(at: destination)
            throw ArchiveError.writeFailed(error.localizedDescription)
        }

        return ExportSummary(
            itemCount: items.count,
            imageCount: imageCount,
            snippetCount: snippets.count
        )
    }

    // MARK: - Import

    func unpack(from url: URL) throws -> UnpackedArchive {
        let temporaryDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("HaoPasteImport-\(UUID().uuidString)", isDirectory: true)

        do {
            try fileManager.createDirectory(
                at: temporaryDirectory,
                withIntermediateDirectories: true
            )
            try runDitto(
                ["-x", "-k", url.path, temporaryDirectory.path],
                failure: ArchiveError.extractionFailed
            )

            guard let historyURL = findFirstFile(named: "history.json", under: temporaryDirectory) else {
                throw ArchiveError.missingHistory
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .millisecondsSince1970
            let items = try decoder.decode(
                [ClipboardItem].self,
                from: Data(contentsOf: historyURL)
            )

            let root = historyURL.deletingLastPathComponent()
            let snippetsURL = root.appendingPathComponent("snippets.json")
            let snippets: [Snippet]
            if fileManager.fileExists(atPath: snippetsURL.path) {
                snippets = try decoder.decode(
                    [Snippet].self,
                    from: Data(contentsOf: snippetsURL)
                )
            } else {
                snippets = []
            }

            let imagesURL = root.appendingPathComponent("Images", isDirectory: true)
            let imagesDirectory = fileManager.fileExists(atPath: imagesURL.path)
                ? imagesURL
                : nil

            var manifest: Manifest?
            let manifestURL = root.appendingPathComponent("manifest.json")
            if fileManager.fileExists(atPath: manifestURL.path) {
                let manifestDecoder = JSONDecoder()
                manifestDecoder.dateDecodingStrategy = .iso8601
                if let data = try? Data(contentsOf: manifestURL) {
                    manifest = try? manifestDecoder.decode(Manifest.self, from: data)
                }
            }

            if let manifest, manifest.schemaVersion > supportedSchemaVersion {
                throw ArchiveError.unsupportedVersion(manifest.schemaVersion)
            }

            return UnpackedArchive(
                items: items,
                snippets: snippets,
                imagesDirectory: imagesDirectory,
                manifest: manifest,
                temporaryDirectory: temporaryDirectory
            )
        } catch let error as ArchiveError {
            try? fileManager.removeItem(at: temporaryDirectory)
            throw error
        } catch {
            try? fileManager.removeItem(at: temporaryDirectory)
            throw ArchiveError.extractionFailed(error.localizedDescription)
        }
    }

    // MARK: - Helpers

    private func runDitto(
        _ arguments: [String],
        failure: (String) -> ArchiveError
    ) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = arguments

        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = Pipe()

        do {
            try process.run()
        } catch {
            throw failure(error.localizedDescription)
        }

        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw failure(message?.isEmpty == false ? message! : "ditto 退出码 \(process.terminationStatus)")
        }
    }

    private func findFirstFile(named name: String, under root: URL) -> URL? {
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        for case let url as URL in enumerator {
            guard url.lastPathComponent.caseInsensitiveCompare(name) == .orderedSame else {
                continue
            }
            if (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true {
                return url
            }
        }

        return nil
    }
}
