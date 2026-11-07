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
    private(set) var isMonitoringPaused = false

    // MARK: - Dependencies

    @ObservationIgnored private let store: ClipboardStore
    @ObservationIgnored private let monitor: ClipboardMonitor
    @ObservationIgnored private var hasStarted = false

    /// Supplied by AppSettings. Evaluated before reading pasteboard data and
    /// again before saving, so excluded sources never enter history.
    @ObservationIgnored var isSourceExcluded: ((SourceApplication) -> Bool)?
    @ObservationIgnored var isImageCaptureEnabled: (() -> Bool)?

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
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        return items
            .filter { filter.matches($0) && $0.matches(trimmedQuery) }
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned {
                    return lhs.isPinned
                }
                return lhs.createdAt > rhs.createdAt
            }
    }

    // MARK: - Actions

    @discardableResult
    func copyToPasteboard(_ item: ClipboardItem) -> Bool {
        let pasteboard = NSPasteboard.general
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

        case .text, .code, .url, .colorHex:
            didWrite = pasteboard.setString(item.content, forType: .string)
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

    func togglePin(_ item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isPinned.toggle()
        store.scheduleSave(items)
    }

    func delete(_ item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let removed = items.remove(at: index)
        store.removeImageAssets(for: [removed])
        store.scheduleSave(items)
    }

    func clearUnpinnedItems() {
        let removed = items.filter { !$0.isPinned }
        guard !removed.isEmpty else { return }

        items.removeAll { !$0.isPinned }
        store.removeImageAssets(for: removed)
        store.scheduleSave(items)
    }

    func clearAllItems() {
        guard !items.isEmpty else { return }

        store.removeImageAssets(for: items)
        items.removeAll()
        store.scheduleSave(items)
    }

    func updateMaxUnpinnedItems(_ limit: Int) {
        let clamped = max(1, limit)
        guard clamped != maxUnpinnedItems else { return }

        maxUnpinnedItems = clamped
        let removed = trimHistory()
        if !removed.isEmpty {
            store.removeImageAssets(for: removed)
        }
        store.scheduleSave(items)
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

    // MARK: - Capture pipeline

    private func handleCapture(_ capture: CapturedClipboard) {
        if let source = capture.sourceApp, isSourceExcluded?(source) == true {
            return
        }

        if case .image = capture.payload, isImageCaptureEnabled?() == false {
            return
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
            item = ClipboardItem(
                type: type,
                content: text,
                plainText: capture.plainText,
                sourceApp: capture.sourceApp,
                contentHash: capture.contentHash
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
            store.removeImageAssets(for: removed)
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
