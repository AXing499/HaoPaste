//
//  PanelViewState.swift
//  HaoPaste
//
//  UI-only state shared by SwiftUI and the keyboard event monitor.
//

import Foundation
import Observation

@MainActor
@Observable
final class PanelViewState {
    var searchText = ""
    var filter: ClipboardFilter = .all
    var selectedID: UUID?
    var selectedSnippetID: UUID?

    /// Additional selection used by multi-select merge. When this set is
    /// empty, only `selectedID` is selected.
    var selectedIDs: Set<UUID> = []
    var selectionAnchorID: UUID?

    /// History item shown in the quick preview overlay, if any.
    var previewingItemID: UUID?

    var isPreviewing: Bool {
        previewingItemID != nil
    }

    var isMultiSelecting: Bool {
        selectedIDs.count > 1
    }

    /// Incremented whenever the search field should take focus.
    var focusToken = 0

    /// Incremented on every panel presentation so the list can scroll to top.
    var presentationToken = 0

    var isSearching: Bool {
        !searchText.isEmpty
    }

    func prepareForPresentation(firstItemID: UUID?) {
        searchText = ""
        filter = .all
        selectedID = firstItemID
        selectedSnippetID = nil
        selectedIDs.removeAll()
        selectionAnchorID = nil
        previewingItemID = nil
        focusToken &+= 1
        presentationToken &+= 1
    }

    // MARK: - Selection

    func isItemSelected(_ id: UUID) -> Bool {
        selectedIDs.isEmpty ? selectedID == id : selectedIDs.contains(id)
    }

    func selectedItems(in items: [ClipboardItem]) -> [ClipboardItem] {
        items.filter { isItemSelected($0.id) }
    }

    /// Command-click: add or remove an item while keeping the existing
    /// selection. The focused item becomes the newly clicked item.
    func toggleMultiSelection(_ item: ClipboardItem, in items: [ClipboardItem]) {
        let ids = Set(items.map(\.id))
        guard ids.contains(item.id) else { return }

        if selectedIDs.isEmpty {
            guard
                let currentID = selectedID,
                currentID != item.id,
                ids.contains(currentID)
            else {
                selectedID = item.id
                selectionAnchorID = item.id
                return
            }

            selectionAnchorID = currentID
            selectedIDs = [currentID]
        }

        if selectedIDs.contains(item.id) {
            selectedIDs.remove(item.id)

            if selectedIDs.count <= 1 {
                let remaining = selectedIDs.first
                selectedIDs.removeAll()
                selectionAnchorID = nil
                selectedID = remaining ?? item.id
            } else if selectedID == item.id {
                selectedID = items.first { selectedIDs.contains($0.id) }?.id
            }
        } else {
            selectedIDs.insert(item.id)
            selectedID = item.id
        }
    }

    /// Shift-click: select the contiguous range between the anchor and the
    /// clicked item, keeping the anchor stable across subsequent shifts.
    func extendSelection(to item: ClipboardItem, in items: [ClipboardItem]) {
        guard let targetIndex = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }

        let anchorID = selectionAnchorID ?? selectedID ?? item.id
        guard let anchorIndex = items.firstIndex(where: { $0.id == anchorID }) else {
            selectedID = item.id
            selectionAnchorID = item.id
            selectedIDs = [item.id]
            return
        }

        let lower = min(anchorIndex, targetIndex)
        let upper = max(anchorIndex, targetIndex)
        selectedIDs = Set(items[lower...upper].map(\.id))
        selectionAnchorID = anchorID
        selectedID = item.id
    }

    func selectAll(in items: [ClipboardItem]) {
        guard items.count > 1 else { return }

        let ids = Set(items.map(\.id))
        selectedIDs = ids
        selectionAnchorID = selectedID.flatMap { ids.contains($0) ? $0 : nil }
            ?? items.first?.id

        if let selectedID, ids.contains(selectedID) {
            return
        }
        selectedID = items.first?.id
    }

    @discardableResult
    func clearMultiSelection() -> Bool {
        guard !selectedIDs.isEmpty else { return false }

        let remaining: UUID?
        if let selectedID, selectedIDs.contains(selectedID) {
            remaining = selectedID
        } else {
            remaining = selectedIDs.first
        }

        selectedIDs.removeAll()
        selectionAnchorID = nil

        if let remaining {
            selectedID = remaining
        }
        return true
    }

    // MARK: - Preview

    func beginPreview(_ item: ClipboardItem) {
        selectedID = item.id
        previewingItemID = item.id
    }

    func togglePreview(_ item: ClipboardItem) {
        if previewingItemID == item.id {
            previewingItemID = nil
        } else {
            selectedID = item.id
            previewingItemID = item.id
        }
    }

    func endPreview() {
        previewingItemID = nil
    }

    func requestSearchFocus() {
        focusToken &+= 1
    }

    func ensureSelection(in items: [ClipboardItem]) {
        let ids = Set(items.map(\.id))

        if !selectedIDs.isEmpty {
            selectedIDs.formIntersection(ids)

            if selectedIDs.count <= 1 {
                let remaining = selectedIDs.first
                selectedIDs.removeAll()
                selectionAnchorID = nil
                if let remaining {
                    selectedID = remaining
                }
            }
        }

        if let selectionAnchorID, !ids.contains(selectionAnchorID) {
            self.selectionAnchorID = nil
        }

        guard !items.isEmpty else {
            selectedID = nil
            selectedIDs.removeAll()
            selectionAnchorID = nil
            return
        }

        if let selectedID, ids.contains(selectedID) {
            return
        }

        if !selectedIDs.isEmpty,
           let firstSelected = items.first(where: { selectedIDs.contains($0.id) }) {
            selectedID = firstSelected.id
            return
        }

        selectedID = items.first?.id
    }

    func moveSelection(in items: [ClipboardItem], by delta: Int) {
        clearMultiSelection()

        guard !items.isEmpty else {
            selectedID = nil
            return
        }

        guard
            let selectedID,
            let currentIndex = items.firstIndex(where: { $0.id == selectedID })
        else {
            self.selectedID = (delta >= 0 ? items.first : items.last)?.id
            return
        }

        let targetIndex = min(max(currentIndex + delta, 0), items.count - 1)
        self.selectedID = items[targetIndex].id
    }

    func moveSelection(in items: [ClipboardItem], by delta: Int, extending: Bool) {
        guard extending else {
            moveSelection(in: items, by: delta)
            return
        }

        guard !items.isEmpty else {
            selectedID = nil
            selectedIDs.removeAll()
            selectionAnchorID = nil
            return
        }

        guard
            let anchorID = selectionAnchorID ?? selectedID ?? items.first?.id,
            let anchorIndex = items.firstIndex(where: { $0.id == anchorID })
        else {
            selectedID = items.first?.id
            return
        }

        let currentIndex = selectedID.flatMap { id in
            items.firstIndex(where: { $0.id == id })
        } ?? anchorIndex
        let targetIndex = min(max(currentIndex + delta, 0), items.count - 1)

        selectedID = items[targetIndex].id
        selectionAnchorID = anchorID

        let lower = min(anchorIndex, targetIndex)
        let upper = max(anchorIndex, targetIndex)
        selectedIDs = Set(items[lower...upper].map(\.id))
    }

    func selectedItem(in items: [ClipboardItem]) -> ClipboardItem? {
        guard let selectedID else { return nil }
        return items.first { $0.id == selectedID }
    }

    func ensureSnippetSelection(in snippets: [Snippet]) {
        guard !snippets.isEmpty else {
            selectedSnippetID = nil
            return
        }

        if let selectedSnippetID, snippets.contains(where: { $0.id == selectedSnippetID }) {
            return
        }

        selectedSnippetID = snippets.first?.id
    }

    func moveSnippetSelection(in snippets: [Snippet], by delta: Int) {
        guard !snippets.isEmpty else {
            selectedSnippetID = nil
            return
        }

        guard
            let selectedSnippetID,
            let currentIndex = snippets.firstIndex(where: { $0.id == selectedSnippetID })
        else {
            self.selectedSnippetID = (delta >= 0 ? snippets.first : snippets.last)?.id
            return
        }

        let targetIndex = min(max(currentIndex + delta, 0), snippets.count - 1)
        self.selectedSnippetID = snippets[targetIndex].id
    }

    func selectedSnippet(in snippets: [Snippet]) -> Snippet? {
        guard let selectedSnippetID else { return nil }
        return snippets.first { $0.id == selectedSnippetID }
    }

    func clearSearch(in itemsAfterClear: [ClipboardItem]) {
        searchText = ""
        ensureSelection(in: itemsAfterClear)
        requestSearchFocus()
    }
}
