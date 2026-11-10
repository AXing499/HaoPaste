//
//  ClipboardManager.swift
//  HaoPaste
//
//  Owns history, de-duplication, pinning, persistence and pasteboard writes.
//

import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class ClipboardManager {
    // MARK: - Observable state

    private(set) var items: [ClipboardItem] = []
    private(set) var trashedItems: [TrashedClipboardItem] = []
    private(set) var isMonitoringPaused = false

    /// How long recently deleted entries stay recoverable.
    var trashRetentionDays = 7

    // MARK: - Dependencies

    @ObservationIgnored private let store: ClipboardStore
    @ObservationIgnored private let monitor: ClipboardMonitor
    @ObservationIgnored private lazy var archiveService = HistoryArchiveService(store: store)
    @ObservationIgnored private var hasStarted = false

    /// Supplied by AppSettings. Evaluated before reading pasteboard data and
    /// again before saving, so excluded sources never enter history.
    @ObservationIgnored var isSourceExcluded: ((SourceApplication) -> Bool)?
    @ObservationIgnored var isImageCaptureEnabled: (() -> Bool)?
    @ObservationIgnored var copyPlainTextOnly: (() -> Bool)?

    /// Pinned items are never removed automatically. The limit is mirrored from
    /// user settings; 200 is the default for a fresh install.
    private(set) var maxUnpinnedItems = 200

    init(store: ClipboardStore? = nil, monitor: ClipboardMonitor? = nil) {
        self.store = store ?? ClipboardStore()
        self.monitor = monitor ?? ClipboardMonitor()
    }

    // MARK: - Lifecycle

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        items = store.loadItems()
        trashedItems = store.loadTrash()
        purgeExpiredTrash()

        monitor.isSourceExcluded = { [weak self] source in
            self?.isSourceExcluded?(source) ?? false
        }
        monitor.isImageCaptureEnabled = { [weak self] in
            self?.isImageCaptureEnabled?() ?? true
        }
        monitor.onCapture = { [weak self] capture in
            self?.handleCapture(capture)
        }
        monitor.start()
    }

    func shutdown() {
        monitor.stop()
        store.saveNow(items)
        store.saveTrashNow(trashedItems)
    }

    // MARK: - Monitoring

    func setMonitoringPaused(_ paused: Bool) {
        guard paused != isMonitoringPaused else { return }
        isMonitoringPaused = paused
        monitor.setPaused(paused)
    }

    func toggleMonitoringPaused() {
        setMonitoringPaused(!isMonitoringPaused)
    }

    // MARK: - Derived state

    var pinnedCount: Int {
        items.lazy.filter(\.isPinned).count
    }

    var unpinnedCount: Int {
        items.count - pinnedCount
    }

    var hasUnpinnedItems: Bool {
        unpinnedCount > 0
    }

    func filteredItems(query: String, filter: ClipboardFilter) -> [ClipboardItem] {
        SearchMatcher().search(items, query: query, filter: filter)
    }

    // MARK: - Actions

    @discardableResult
    func copyToPasteboard(_ item: ClipboardItem) -> Bool {
        let pasteboard = monitor.pasteboard
        pasteboard.clearContents()

        let didWrite: Bool
        switch item.type {
        case .image:
            guard
                let imageURL = store.imageURL(for: item),
                let data = try? Data(contentsOf: imageURL)
            else {
                NSSound.beep()
                return false
            }
            didWrite = pasteboard.setData(data, forType: .png)

        case .file:
            let urls = item.availableFileURLs
            guard !urls.isEmpty else {
                NSSound.beep()
                return false
            }
            didWrite = pasteboard.writeObjects(urls as [NSURL])

        case .text, .code, .url, .colorHex:
            didWrite = pasteboard.setString(item.content, forType: .string)
            if item.hasRichText,
               copyPlainTextOnly?() != true,
               let richText = store.loadRichText(for: item) {
                if let rtfData = richText.rtfData {
                    pasteboard.setData(rtfData, forType: .rtf)
                }
                if let htmlData = richText.htmlData {
                    pasteboard.setData(htmlData, forType: .html)
                }
            }
        }

        // Our own write must not create a duplicate history entry.
        monitor.synchronizeChangeCount()

        guard didWrite else {
            NSSound.beep()
            return false
        }

        // Copying an old entry refreshes its recency for the next presentation.
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].createdAt = .now
            store.scheduleSave(items)
        }

        return true
    }

    /// Writes only plain text without adding a duplicate history entry. Used
    /// by the explicit "copy as plain text" action and when the user asks all
    /// rich-text copies to be plain.
    @discardableResult
    func copyPlainTextToPasteboard(_ text: String) -> Bool {
        let pasteboard = monitor.pasteboard
        pasteboard.clearContents()
        let didWrite = pasteboard.setString(text, forType: .string)
        monitor.synchronizeChangeCount()

        if !didWrite {
            NSSound.beep()
        }
        return didWrite
    }

    /// Writes text produced inside HaoPaste (OCR, translation, snippets and
    /// other derived actions) and keeps it in history, just like a normal copy.
    @discardableResult
    func copyTextToPasteboard(_ text: String) -> Bool {
        let pasteboard = monitor.pasteboard
        pasteboard.clearContents()
        let didWrite = pasteboard.setString(text, forType: .string)
        monitor.synchronizeChangeCount()

        guard didWrite else {
            NSSound.beep()
            return false
        }

        captureGeneratedText(text)
        return true
    }

    private func captureGeneratedText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let type = ContentClassifier.classify(text)
        handleCapture(
            CapturedClipboard(
                payload: .text(text, type: type),
                plainText: text,
                contentHash: ContentHasher.text(text, type: type),
                sourceApp: nil
            )
        )
    }

    /// Writes multiple entries as one payload without adding a history record.
    @discardableResult
    func copyMergedToPasteboard(_ items: [ClipboardItem]) -> Bool {
        switch MergedContentBuilder.make(from: items) {
        case let .text(text):
            return copyTextToPasteboard(text)

        case let .fileURLs(urls):
            let pasteboard = monitor.pasteboard
            pasteboard.clearContents()
            let didWrite = pasteboard.writeObjects(urls as [NSURL])
            monitor.synchronizeChangeCount()

            if !didWrite {
                NSSound.beep()
            }
            return didWrite

        case .unsupported:
            NSSound.beep()
            return false
        }
    }

    func togglePin(_ item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isPinned.toggle()
        store.scheduleSave(items)
    }

    func delete(_ item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let removed = items.remove(at: index)
        trashedItems.removeAll { $0.id == removed.id }
        trashedItems.insert(
            TrashedClipboardItem(item: removed, deletedAt: .now),
            at: 0
        )
        store.scheduleSave(items)
        store.scheduleSaveTrash(trashedItems)
    }

    // MARK: - Recently deleted

    func updateTrashRetention(_ days: Int) {
        let clamped = max(1, days)
        guard clamped != trashRetentionDays else {
            purgeExpiredTrash()
            return
        }
        trashRetentionDays = clamped
        purgeExpiredTrash()
    }

    func restore(_ entry: TrashedClipboardItem) {
        guard let index = trashedItems.firstIndex(where: { $0.id == entry.id }) else {
            return
        }
        let removed = trashedItems.remove(at: index)

        // If the same content is already back in history, just clear the
        // duplicate trash entry instead of inserting a second copy.
        if items.contains(where: { $0.contentHash == removed.item.contentHash }) {
            store.removeAssets(for: [removed.item])
        } else {
            var restored = removed.item
            restored.createdAt = .now
            items.insert(restored, at: 0)

            let trimmed = trimHistory()
            if !trimmed.isEmpty {
                store.removeAssets(for: trimmed)
            }
        }

        store.scheduleSave(items)
        store.scheduleSaveTrash(trashedItems)
    }

    func permanentlyDelete(_ entry: TrashedClipboardItem) {
        guard let index = trashedItems.firstIndex(where: { $0.id == entry.id }) else {
            return
        }
        let removed = trashedItems.remove(at: index)
        store.removeAssets(for: [removed.item])
        store.scheduleSaveTrash(trashedItems)
    }

    func emptyTrash() {
        guard !trashedItems.isEmpty else { return }
        store.removeAssets(for: trashedItems.map(\.item))
        trashedItems.removeAll()
        store.scheduleSaveTrash(trashedItems)
    }

    func purgeExpiredTrash(now: Date = .now) {
        guard !trashedItems.isEmpty else { return }
        let cutoff = now.addingTimeInterval(
            -Double(max(1, trashRetentionDays)) * 24 * 60 * 60
        )
        let expired = trashedItems.filter { $0.deletedAt < cutoff }
        guard !expired.isEmpty else { return }

        trashedItems.removeAll { $0.deletedAt < cutoff }
        store.removeAssets(for: expired.map(\.item))
        store.scheduleSaveTrash(trashedItems)
    }

    func clearUnpinnedItems() {
        let removed = items.filter { !$0.isPinned }
        guard !removed.isEmpty else { return }

        items.removeAll { !$0.isPinned }
        store.removeAssets(for: removed)
        store.scheduleSave(items)
    }

    func clearAllItems() {
        guard !items.isEmpty else { return }

        store.removeAssets(for: items)
        items.removeAll()
        store.scheduleSave(items)
    }

    func updateMaxUnpinnedItems(_ limit: Int) {
        let clamped = max(1, limit)
        guard clamped != maxUnpinnedItems else { return }

        maxUnpinnedItems = clamped
        let removed = trimHistory()
        if !removed.isEmpty {
            store.removeAssets(for: removed)
        }
        store.scheduleSave(items)
    }

    // MARK: - Backup

    func exportHistory(
        to url: URL,
        snippets: [Snippet] = []
    ) throws -> HistoryArchiveService.ExportSummary {
        try archiveService.export(items: items, snippets: snippets, to: url)
    }

    func importHistory(from url: URL) throws -> HistoryArchiveService.ImportSummary {
        let archive = try archiveService.unpack(from: url)
        defer {
            try? FileManager.default.removeItem(at: archive.temporaryDirectory)
        }

        var importedCount = 0
        var mergedPinnedCount = 0
        var skippedCount = 0
        var newItems: [ClipboardItem] = []
        var seenHashes = Set(items.map(\.contentHash))

        for imported in archive.items {
            guard !imported.contentHash.isEmpty else {
                skippedCount += 1
                continue
            }

            if let existingIndex = items.firstIndex(where: {
                $0.contentHash == imported.contentHash
            }) {
                if imported.isPinned, !items[existingIndex].isPinned {
                    items[existingIndex].isPinned = true
                    mergedPinnedCount += 1
                } else {
                    skippedCount += 1
                }
                continue
            }

            guard !seenHashes.contains(imported.contentHash) else {
                skippedCount += 1
                continue
            }
            seenHashes.insert(imported.contentHash)

            if imported.type == .image {
                guard let imagesDirectory = archive.imagesDirectory else {
                    skippedCount += 1
                    continue
                }

                do {
                    guard let importedImage = try store.importImageItem(
                        imported,
                        fromImagesDirectory: imagesDirectory
                    ) else {
                        skippedCount += 1
                        continue
                    }
                    newItems.append(importedImage)
                } catch {
                    NSLog("HaoPaste: could not import image item — \(error.localizedDescription)")
                    skippedCount += 1
                    continue
                }
            } else {
                var richTextFileName: String?
                if let richTextDirectory = archive.richTextDirectory {
                    richTextFileName = try? store.importRichTextFile(
                        for: imported,
                        from: richTextDirectory
                    )
                }

                newItems.append(
                    ClipboardItem(
                        id: UUID(),
                        type: imported.type,
                        content: imported.content,
                        plainText: imported.plainText,
                        isPinned: imported.isPinned,
                        createdAt: imported.createdAt,
                        sourceApp: imported.sourceApp,
                        contentHash: imported.contentHash,
                        filePaths: imported.filePaths,
                        richTextFileName: richTextFileName
                    )
                )
            }

            importedCount += 1
        }

        items.append(contentsOf: newItems)
        let removed = trimHistory()
        if !removed.isEmpty {
            store.removeAssets(for: removed)
        }

        if importedCount > 0 || mergedPinnedCount > 0 {
            store.scheduleSave(items)
        }

        return HistoryArchiveService.ImportSummary(
            importedCount: importedCount,
            mergedPinnedCount: mergedPinnedCount,
            skippedCount: skippedCount,
            trimmedCount: removed.count,
            snippets: archive.snippets
        )
    }

    var storageDirectoryURL: URL {
        store.baseDirectoryURL
    }

    func imageURL(for item: ClipboardItem) -> URL? {
        store.imageURL(for: item)
    }

    func thumbnailURL(for item: ClipboardItem) -> URL? {
        store.thumbnailURL(for: item)
    }

    func richText(for item: ClipboardItem) -> RichTextPayload? {
        store.loadRichText(for: item)
    }

    // MARK: - Capture pipeline

    private func handleCapture(_ capture: CapturedClipboard) {
        if let source = capture.sourceApp, isSourceExcluded?(source) == true {
            return
        }

        if case .image = capture.payload, isImageCaptureEnabled?() == false {
            return
        }

        if let trashedIndex = trashedItems.firstIndex(
            where: { $0.item.contentHash == capture.contentHash }
        ) {
            let removed = trashedItems.remove(at: trashedIndex)
            store.removeAssets(for: [removed.item])
            store.scheduleSaveTrash(trashedItems)
        }

        // De-duplication: an identical entry is moved to the top, keeping its
        // pinned state and identity.
        if let existingIndex = items.firstIndex(where: { $0.contentHash == capture.contentHash }) {
            var existing = items.remove(at: existingIndex)
            existing.createdAt = .now
            if let sourceApp = capture.sourceApp {
                existing.sourceApp = sourceApp
            }
            items.insert(existing, at: 0)
            store.scheduleSave(items)
            return
        }

        let item: ClipboardItem

        switch capture.payload {
        case let .text(text, type):
            let id = UUID()
            var richTextFileName: String?

            if let richText = capture.richText {
                do {
                    richTextFileName = try store.saveRichText(richText, id: id)
                } catch {
                    NSLog("HaoPaste: failed to store rich text — \(error.localizedDescription)")
                }
            }

            item = ClipboardItem(
                id: id,
                type: type,
                content: text,
                plainText: capture.plainText,
                sourceApp: capture.sourceApp,
                contentHash: capture.contentHash,
                richTextFileName: richTextFileName
            )

        case let .files(paths):
            item = ClipboardItem(
                type: .file,
                content: paths.joined(separator: "\n"),
                plainText: capture.plainText,
                sourceApp: capture.sourceApp,
                contentHash: capture.contentHash,
                filePaths: paths
            )

        case let .image(data, _):
            let id = UUID()
            do {
                let storedImage = try store.saveImage(data: data, id: id)
                item = ClipboardItem(
                    id: id,
                    type: .image,
                    content: storedImage.fileName,
                    plainText: capture.plainText,
                    sourceApp: capture.sourceApp,
                    contentHash: capture.contentHash,
                    imageFileName: storedImage.fileName,
                    thumbnailFileName: storedImage.thumbnailFileName,
                    imageDimensions: storedImage.dimensions
                )
            } catch {
                NSLog("HaoPaste: failed to store image — \(error.localizedDescription)")
                return
            }
        }

        items.insert(item, at: 0)

        let removed = trimHistory()
        if !removed.isEmpty {
            store.removeAssets(for: removed)
        }

        store.scheduleSave(items)
    }

    /// FIFO trimming that never touches pinned entries. Removal is based on
    /// `createdAt`, not array order, because recently re-used entries can be
    /// refreshed while staying at their original array position.
    private func trimHistory() -> [ClipboardItem] {
        let unpinnedItems = items.filter { !$0.isPinned }
        let overflowCount = unpinnedItems.count - maxUnpinnedItems
        guard overflowCount > 0 else { return [] }

        let removalIDs = Set(
            unpinnedItems
                .sorted { $0.createdAt < $1.createdAt }
                .prefix(overflowCount)
                .map(\.id)
        )

        guard !removalIDs.isEmpty else { return [] }

        let removed = items.filter { removalIDs.contains($0.id) }
        items.removeAll { removalIDs.contains($0.id) }
        return removed
    }
}

#if DEBUG
extension ClipboardManager {
    /// Populates a fresh store with representative content for visual QA.
    func seedDemoDataIfNeeded() {
        guard items.isEmpty else { return }
        items = DemoContent.makeItems(store: store)
        store.saveNow(items)
    }
}
#endif
