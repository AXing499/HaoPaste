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
        focusToken &+= 1
        presentationToken &+= 1
    }

    func requestSearchFocus() {
        focusToken &+= 1
    }

    func ensureSelection(in items: [ClipboardItem]) {
        guard !items.isEmpty else {
            selectedID = nil
            return
        }

        if let selectedID, items.contains(where: { $0.id == selectedID }) {
            return
        }

        selectedID = items.first?.id
    }

    func moveSelection(in items: [ClipboardItem], by delta: Int) {
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
