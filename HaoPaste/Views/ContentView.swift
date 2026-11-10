//
//  ContentView.swift
//  HaoPaste
//
//  The floating clipboard panel: search, category pills and history list.
//

import AppKit
import SwiftUI

struct ContentView: View {
    @Environment(ClipboardManager.self) private var manager
    @Environment(SnippetManager.self) private var snippetManager
    @Environment(TranslationService.self) private var translationService
    @Environment(OCRService.self) private var ocrService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Bindable var state: PanelViewState
    let onCopy: (ClipboardItem) -> Void
    let onCopyMerged: ([ClipboardItem]) -> Void
    let onCopyText: (String) -> Void
    let onCopyPlainText: (String) -> Void
    let onCopySnippet: (Snippet) -> Void

    @FocusState private var isSearchFocused: Bool
    @State private var snippetEditor: SnippetEditorTarget?

    private var isSnippetMode: Bool {
        state.filter == .snippets
    }

    private var isTrashMode: Bool {
        state.filter == .trash
    }

    private var visibleItems: [ClipboardItem] {
        isSnippetMode
            ? []
            : manager.filteredItems(query: state.searchText, filter: state.filter)
    }

    private var visibleSnippets: [Snippet] {
        isSnippetMode
            ? snippetManager.filtered(query: state.searchText)
            : []
    }

    private var visibleTrash: [TrashedClipboardItem] {
        guard isTrashMode else { return [] }
        let query = state.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return manager.trashedItems }
        return manager.trashedItems.filter { $0.item.matches(query) }
    }

    private var visibleIDs: [UUID] {
        visibleItems.map(\.id)
    }

    private var visibleSnippetIDs: [UUID] {
        visibleSnippets.map(\.id)
    }

    private var previewItem: ClipboardItem? {
        guard let id = state.previewingItemID else { return nil }
        return visibleItems.first { $0.id == id }
    }

    private var selectedHistoryItems: [ClipboardItem] {
        visibleItems.filter { state.isItemSelected($0.id) }
    }

    private var mergedSelection: MergedClipboardContent {
        MergedContentBuilder.make(from: selectedHistoryItems)
    }

    private var selectedImageItems: [(ClipboardItem, URL)] {
        selectedHistoryItems.compactMap { item in
            guard item.type == .image,
                  let imageURL = manager.imageURL(for: item)
            else {
                return nil
            }
            return (item, imageURL)
        }
    }

    private var canBatchRecognizeImages: Bool {
        state.isMultiSelecting
            && selectedHistoryItems.count > 1
            && selectedImageItems.count == selectedHistoryItems.count
    }

    private var canMergeSelection: Bool {
        if case .unsupported = mergedSelection {
            return false
        }
        return true
    }

    private var mergeHint: String? {
        guard state.isMultiSelecting else { return nil }

        if case .unsupported = mergedSelection {
            if selectedHistoryItems.contains(where: { $0.type == .image }) {
                return canBatchRecognizeImages
                    ? "可批量识别图片文字"
                    : "图片暂不支持合并"
            }
            return "没有可复制的内容"
        }

        return nil
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header
                contentList
                PanelFooterView(
                    isPaused: manager.isMonitoringPaused,
                    itemCount: isSnippetMode
                        ? snippetManager.snippets.count
                        : isTrashMode
                            ? manager.trashedItems.count
                            : manager.items.count,
                    itemLabel: isSnippetMode
                        ? "个片段"
                        : isTrashMode
                            ? "条最近删除"
                            : "条记录",
                    isSearching: state.isSearching
                )
            }

            if let previewItem {
                PreviewOverlayView(
                    item: previewItem,
                    imageURL: manager.imageURL(for: previewItem),
                    richText: manager.richText(for: previewItem),
                    onClose: {
                        withAnimation(reduceMotion ? nil : Theme.spring) {
                            state.endPreview()
                        }
                    },
                    onCopy: {
                        onCopy(previewItem)
                    },
                    onCopyText: onCopyText,
                    onOpenURL: { url in
                        NSWorkspace.shared.open(url)
                    },
                    onOpenFiles: {
                        for url in previewItem.availableFileURLs {
                            NSWorkspace.shared.open(url)
                        }
                    },
                    onRevealFiles: {
                        let urls = previewItem.availableFileURLs
                        guard !urls.isEmpty else { return }
                        NSWorkspace.shared.activateFileViewerSelecting(urls)
                    },
                    onSaveImage: {
                        guard let imageURL = manager.imageURL(for: previewItem) else { return }
                        ImageSavePanel.present(imageURL: imageURL)
                    },
                    onTranslate: {
                        translationService.present(item: previewItem)
                    },
                    onExtractText: {
                        guard let imageURL = manager.imageURL(for: previewItem) else { return }
                        ocrService.present(item: previewItem, imageURL: imageURL)
                    },
                    onExtractAndTranslate: {
                        guard let imageURL = manager.imageURL(for: previewItem) else { return }
                        ocrService.present(
                            item: previewItem,
                            imageURL: imageURL,
                            translateAfterRecognition: true
                        )
                    }
                )
                .zIndex(1)
                .transition(.opacity)
            }

            if ocrService.isPresenting {
                Group {
                    if ocrService.isBatchMode {
                        BatchOCRPaneView(
                            service: ocrService,
                            onCopyAll: onCopyText,
                            onCopyEntry: { text in
                                _ = manager.copyTextToPasteboard(text)
                            },
                            onTranslateEntry: { text, title in
                                translationService.present(
                                    text: text,
                                    title: title
                                )
                            },
                            onSaveSnippet: { text in
                                saveOCRSnippet(
                                    text,
                                    title: "批量识图 · \(ocrService.batchEntries.count) 张"
                                )
                            },
                            onClose: {
                                ocrService.close()
                                state.requestSearchFocus()
                            }
                        )
                    } else {
                        OCRPaneView(
                            service: ocrService,
                            onCopyText: onCopyText,
                            onTranslate: { text in
                                translationService.present(
                                    text: text,
                                    title: "图片文字 · \(ocrService.sourceTitle)"
                                )
                            },
                            onSaveSnippet: { text in
                                saveOCRSnippet(text)
                            },
                            onClose: {
                                ocrService.close()
                                state.requestSearchFocus()
                            }
                        )
                    }
                }
                .zIndex(2)
                .transition(.opacity)
            }

            if translationService.isPresenting {
                TranslationPaneView(
                    service: translationService,
                    onCopyTranslation: onCopyText,
                    onCopyBilingual: onCopyText,
                    onSaveSnippet: { text in
                        saveTranslationSnippet(text)
                    },
                    onClose: {
                        translationService.close()
                        state.requestSearchFocus()
                    }
                )
                .zIndex(3)
                .transition(.opacity)
            }

            if let editor = snippetEditor {
                SnippetEditorOverlay(
                    title: editor.title,
                    content: editor.content,
                    isEditing: editor.snippet != nil,
                    onSave: { title, content in
                        saveSnippet(editor: editor, title: title, content: content)
                    },
                    onCancel: {
                        dismissSnippetEditor()
                    }
                )
                .zIndex(20)
                .transition(.opacity)
            }
        }
        .frame(width: Theme.panelSize.width, height: Theme.panelSize.height)
        .background {
            panelBackground
        }
        .clipShape(Theme.panelShape)
        .hairlineStroke(Theme.panelShape)
        .padding(Theme.windowPadding)
        .onAppear {
            ensureSelectionForCurrentMode()
            isSearchFocused = true
        }
        .onChange(of: state.focusToken) { _, _ in
            isSearchFocused = true
        }
        .onChange(of: state.presentationToken) { _, _ in
            snippetEditor = nil
            state.isEditingSnippet = false
        }
        .onChange(of: state.searchText) { _, _ in
            state.endPreview()
            state.clearMultiSelection()
            ensureSelectionForCurrentMode()
        }
        .onChange(of: state.filter) { _, _ in
            state.endPreview()
            state.clearMultiSelection()
            ensureSelectionForCurrentMode()
        }
        .onChange(of: visibleIDs) { _, ids in
            guard !isSnippetMode else { return }
            if let previewingItemID = state.previewingItemID, !ids.contains(previewingItemID) {
                state.endPreview()
            }
            state.ensureSelection(in: visibleItems)
        }
        .onChange(of: visibleSnippetIDs) { _, _ in
            guard isSnippetMode else { return }
            state.ensureSnippetSelection(in: visibleSnippets)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            searchBar

            HStack(spacing: 10) {
                FilterTabsView(selection: $state.filter)

                Spacer(minLength: 8)

                if isSnippetMode {
                    Button {
                        presentNewSnippet()
                    } label: {
                        Label("新建片段", systemImage: "plus")
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 9)
                            .frame(height: 22)
                            .background {
                                Capsule()
                                    .fill(Color.accentColor.opacity(0.10))
                            }
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                    .help("新建片段")
                }

                if isTrashMode {
                    Button {
                        confirmEmptyTrash()
                    } label: {
                        Label("清空", systemImage: "trash")
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.secondary)
                            .padding(.horizontal, 9)
                            .frame(height: 22)
                            .background {
                                Capsule()
                                    .fill(Color.primary.opacity(0.05))
                            }
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                    .disabled(manager.trashedItems.isEmpty)
                    .help("清空最近删除")
                }

                Text(
                    isSnippetMode
                        ? "\(visibleSnippets.count) 个片段"
                        : isTrashMode
                            ? "\(visibleTrash.count) 条最近删除"
                            : "\(visibleItems.count) 条"
                )
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
                .contentTransition(.numericText())
                .animation(
                    reduceMotion ? nil : Theme.spring,
                    value: isSnippetMode
                        ? visibleSnippets.count
                        : isTrashMode
                            ? visibleTrash.count
                            : visibleItems.count
                )
            }
        }
        .padding(.horizontal, Theme.contentPadding)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var searchBar: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)

            TextField(
                isSnippetMode
                    ? "搜索片段…"
                    : isTrashMode
                        ? "搜索最近删除…"
                        : "搜索剪切板历史…",
                text: $state.searchText
            )
            .textFieldStyle(.plain)
            .font(.system(.body, design: .rounded))
            .focusEffectDisabled()
            .focused($isSearchFocused)
            .help("支持中文、拼音缩写、来源应用与模糊匹配")
            .onSubmit {
                copySelectedEntry()
            }

            if !state.searchText.isEmpty {
                Button {
                    withAnimation(reduceMotion ? nil : Theme.quickSpring) {
                        state.searchText = ""
                    }
                    state.requestSearchFocus()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.tertiary)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .focusable(false)
                .help("清除搜索")
                .transition(.scale(scale: 0.7).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
        .background {
            Capsule(style: .continuous)
                .fill(Color.primary.opacity(isSearchFocused ? 0.065 : 0.05))
        }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(
                    isSearchFocused
                        ? Color.accentColor.opacity(0.3)
                        : Theme.hairlineColor,
                    lineWidth: Theme.hairline
                )
        }
        .contentShape(Capsule(style: .continuous))
        .onTapGesture {
            isSearchFocused = true
        }
        .animation(reduceMotion ? nil : Theme.spring, value: isSearchFocused)
        .animation(reduceMotion ? nil : Theme.spring, value: state.searchText.isEmpty)
    }

    // MARK: - List

    @ViewBuilder
    private var contentList: some View {
        if isSnippetMode {
            snippetList
        } else if isTrashMode {
            trashList
        } else {
            historyList
        }
    }

    private var historyList: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(spacing: Theme.rowSpacing) {
                    Color.clear
                        .frame(height: 0)
                        .id("list-top")

                    ForEach(Array(visibleItems.enumerated()), id: \.element.id) { index, item in
                        ItemRowView(
                            item: item,
                            index: index,
                            thumbnailURL: manager.thumbnailURL(for: item),
                            imageURL: manager.imageURL(for: item),
                            dragProvider: {
                                ItemDragProvider.make(
                                    for: item,
                                    imageURL: manager.imageURL(for: item),
                                    richText: manager.richText(for: item)
                                )
                            },
                            isSelected: state.isItemSelected(item.id),
                            isMultiSelected: state.isMultiSelecting
                                && state.selectedIDs.contains(item.id),
                            onRowClick: {
                                if NSEvent.modifierFlags.contains(.command) {
                                    withAnimation(reduceMotion ? nil : Theme.spring) {
                                        state.toggleMultiSelection(item, in: visibleItems)
                                    }
                                } else if NSEvent.modifierFlags.contains(.shift) {
                                    withAnimation(reduceMotion ? nil : Theme.spring) {
                                        state.extendSelection(to: item, in: visibleItems)
                                    }
                                } else {
                                    onCopy(item)
                                }
                            },
                            onCopy: {
                                onCopy(item)
                            },
                            onCopyText: onCopyText,
                            onCopyPlainText: {
                                onCopyPlainText(item.plainText)
                            },
                            onSaveSnippet: {
                                presentSnippetEditor(for: item)
                            },
                            onPreview: {
                                state.beginPreview(item)
                            },
                            onTranslate: {
                                translationService.present(item: item)
                            },
                            onExtractText: {
                                guard let imageURL = manager.imageURL(for: item) else { return }
                                ocrService.present(item: item, imageURL: imageURL)
                            },
                            onExtractAndTranslate: {
                                guard let imageURL = manager.imageURL(for: item) else { return }
                                ocrService.present(
                                    item: item,
                                    imageURL: imageURL,
                                    translateAfterRecognition: true
                                )
                            },
                            onTogglePin: {
                                withAnimation(reduceMotion ? nil : Theme.spring) {
                                    manager.togglePin(item)
                                }
                            },
                            onDelete: {
                                withAnimation(reduceMotion ? nil : Theme.gentleSpring) {
                                    manager.delete(item)
                                }
                            }
                        )
                        .id(item.id)
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)),
                                removal: .opacity.combined(with: .scale(scale: 0.98))
                            )
                        )
                    }
                }
                .padding(.horizontal, Theme.contentPadding)
                .padding(.top, 2)
                .padding(.bottom, state.isMultiSelecting ? 56 : 6)
                .animation(reduceMotion ? nil : Theme.gentleSpring, value: visibleIDs)
            }
            .scrollIndicators(.never)
            .overlay {
                if visibleItems.isEmpty {
                    EmptyStateView(query: state.searchText, filter: state.filter)
                }
            }
            .overlay(alignment: .bottom) {
                if state.isMultiSelecting {
                    MultiSelectionBar(
                        count: selectedHistoryItems.count,
                        hint: mergeHint,
                        canMerge: canMergeSelection,
                        onMerge: {
                            onCopyMerged(selectedHistoryItems)
                        },
                        onRecognizeText: canBatchRecognizeImages ? {
                            ocrService.presentBatch(items: selectedImageItems)
                        } : nil,
                        onClear: {
                            withAnimation(reduceMotion ? nil : Theme.spring) {
                                _ = state.clearMultiSelection()
                            }
                        }
                    )
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(
                reduceMotion ? nil : Theme.spring,
                value: state.isMultiSelecting
            )
            .onChange(of: state.selectedID) { _, selectedID in
                guard let selectedID else { return }
                withAnimation(reduceMotion ? nil : Theme.spring) {
                    proxy.scrollTo(selectedID, anchor: .center)
                }
            }
            .onChange(of: state.presentationToken) { _, _ in
                isSearchFocused = true
                proxy.scrollTo("list-top", anchor: .top)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var trashList: some View {
        ScrollView {
            LazyVStack(spacing: Theme.rowSpacing) {
                ForEach(visibleTrash) { entry in
                    TrashRowView(
                        entry: entry,
                        retentionDays: manager.trashRetentionDays,
                        onRestore: {
                            restoreTrash(entry)
                        },
                        onDelete: {
                            confirmDeleteTrash(entry)
                        }
                    )
                    .transition(
                        .asymmetric(
                            insertion: .opacity,
                            removal: .opacity.combined(with: .scale(scale: 0.98))
                        )
                    )
                }
            }
            .padding(.horizontal, Theme.contentPadding)
            .padding(.top, 2)
            .padding(.bottom, 6)
            .animation(reduceMotion ? nil : Theme.gentleSpring, value: visibleTrash.map(\.id))
        }
        .scrollIndicators(.never)
        .overlay {
            if visibleTrash.isEmpty {
                TrashEmptyStateView(
                    query: state.searchText,
                    retentionDays: manager.trashRetentionDays
                )
            }
        }
    }

    private var snippetList: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(spacing: Theme.rowSpacing) {
                    Color.clear
                        .frame(height: 0)
                        .id("list-top")

                    ForEach(Array(visibleSnippets.enumerated()), id: \.element.id) { index, snippet in
                        SnippetRowView(
                            snippet: snippet,
                            index: index,
                            isSelected: state.selectedSnippetID == snippet.id,
                            onCopy: {
                                onCopySnippet(snippet)
                            },
                            onEdit: {
                                presentSnippetEditor(snippet)
                            },
                            onDelete: {
                                confirmDeleteSnippet(snippet)
                            }
                        )
                        .id(snippet.id)
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)),
                                removal: .opacity.combined(with: .scale(scale: 0.98))
                            )
                        )
                    }
                }
                .padding(.horizontal, Theme.contentPadding)
                .padding(.top, 2)
                .padding(.bottom, 6)
                .animation(reduceMotion ? nil : Theme.gentleSpring, value: visibleSnippetIDs)
            }
            .scrollIndicators(.never)
            .overlay {
                if visibleSnippets.isEmpty {
                    SnippetEmptyStateView(query: state.searchText)
                }
            }
            .onChange(of: state.selectedSnippetID) { _, selectedID in
                guard let selectedID else { return }
                withAnimation(reduceMotion ? nil : Theme.spring) {
                    proxy.scrollTo(selectedID, anchor: .center)
                }
            }
            .onChange(of: state.presentationToken) { _, _ in
                isSearchFocused = true
                proxy.scrollTo("list-top", anchor: .top)
            }
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Background

    private var panelBackground: some View {
        ZStack {
            Rectangle()
                .fill(.regularMaterial)

            LinearGradient(
                colors: [
                    Color.primary.opacity(0.025),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .center
            )
        }
    }

    // MARK: - Actions

    private func ensureSelectionForCurrentMode() {
        if isSnippetMode {
            state.ensureSnippetSelection(in: visibleSnippets)
        } else if isTrashMode {
            state.selectedID = nil
            state.clearMultiSelection()
        } else {
            state.ensureSelection(in: visibleItems)
        }
    }

    private func restoreTrash(_ entry: TrashedClipboardItem) {
        withAnimation(reduceMotion ? nil : Theme.gentleSpring) {
            manager.restore(entry)
        }
    }

    private func confirmDeleteTrash(_ entry: TrashedClipboardItem) {
        let alert = NSAlert()
        alert.messageText = "彻底删除这条记录？"
        alert.informativeText = "此操作无法撤销。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "彻底删除")
        alert.addButton(withTitle: "取消")

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        withAnimation(reduceMotion ? nil : Theme.gentleSpring) {
            manager.permanentlyDelete(entry)
        }
    }

    private func confirmEmptyTrash() {
        guard !manager.trashedItems.isEmpty else { return }

        let alert = NSAlert()
        alert.messageText = "清空最近删除？"
        alert.informativeText = "所有最近删除的记录将被永久删除，此操作无法撤销。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "清空")
        alert.addButton(withTitle: "取消")

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        withAnimation(reduceMotion ? nil : Theme.gentleSpring) {
            manager.emptyTrash()
        }
    }

    private func presentNewSnippet() {
        snippetEditor = SnippetEditorTarget(
            snippet: nil,
            title: "",
            content: ""
        )
        state.isEditingSnippet = true
        isSearchFocused = false
    }

    private func presentSnippetEditor(_ snippet: Snippet) {
        snippetEditor = SnippetEditorTarget(
            snippet: snippet,
            title: snippet.title,
            content: snippet.content
        )
        state.isEditingSnippet = true
        isSearchFocused = false
    }

    private func presentSnippetEditor(for item: ClipboardItem) {
        let title = item.displayTitle
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let content = item.plainText.isEmpty ? item.content : item.plainText
        snippetEditor = SnippetEditorTarget(
            snippet: nil,
            title: title.isEmpty ? "未命名片段" : String(title.prefix(40)),
            content: content
        )
        state.isEditingSnippet = true
        isSearchFocused = false
    }

    private func saveSnippet(
        editor: SnippetEditorTarget,
        title: String,
        content: String
    ) {
        if let snippet = editor.snippet {
            snippetManager.update(snippet, title: title, content: content)
            dismissSnippetEditor()
        } else if let created = snippetManager.create(
            title: title,
            content: content
        ) {
            state.selectedSnippetID = created.id
            dismissSnippetEditor()
        }
        ensureSelectionForCurrentMode()
    }

    private func dismissSnippetEditor() {
        snippetEditor = nil
        state.isEditingSnippet = false
        state.requestSearchFocus()
    }

    private func confirmDeleteSnippet(_ snippet: Snippet) {
        let alert = NSAlert()
        alert.messageText = "删除片段「\(snippet.title)」？"
        alert.informativeText = "此操作无法撤销。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        snippetManager.delete(snippet)
        ensureSelectionForCurrentMode()
        state.requestSearchFocus()
    }

    private func saveOCRSnippet(_ text: String, title: String? = nil) {
        guard !text.isEmpty else { return }

        let rawTitle = title ?? ocrService.sourceTitle
        let trimmedTitle = rawTitle.count > 20
            ? String(rawTitle.prefix(20)) + "…"
            : rawTitle
        _ = snippetManager.create(
            title: "识图 · \(trimmedTitle)",
            content: text
        )
    }

    private func saveTranslationSnippet(_ text: String) {
        guard !text.isEmpty else { return }

        let rawTitle = translationService.sourceTitle
        let title = rawTitle.count > 24
            ? String(rawTitle.prefix(24)) + "…"
            : rawTitle
        _ = snippetManager.create(
            title: "翻译 · \(title)",
            content: text
        )
    }

    private func copySelectedEntry() {
        if isSnippetMode {
            guard
                let snippet = state.selectedSnippet(in: visibleSnippets)
                    ?? visibleSnippets.first
            else {
                return
            }
            onCopySnippet(snippet)
        } else {
            copySelectedItem()
        }
    }

    private func copySelectedItem() {
        guard let item = state.selectedItem(in: visibleItems) ?? visibleItems.first else {
            return
        }
        onCopy(item)
    }
}

private struct SnippetEditorTarget: Identifiable {
    let id = UUID()
    let snippet: Snippet?
    let title: String
    let content: String
}

private struct SnippetEditorOverlay: View {
    let title: String
    let content: String
    let isEditing: Bool
    let onSave: (String, String) -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .contentShape(Rectangle())
                .onTapGesture(perform: onCancel)

            SnippetEditorSheet(
                title: title,
                content: content,
                isEditing: isEditing,
                onSave: onSave,
                onCancel: onCancel
            )
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.hairlineColor, lineWidth: Theme.hairline)
            }
            .shadow(color: Color.black.opacity(0.24), radius: 24, x: 0, y: 10)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .onTapGesture {}
        }
    }
}

#if DEBUG
#Preview("HaoPaste Panel") {
    let manager = ClipboardManager()
    let snippets = SnippetManager()
    ContentView(
        state: PanelViewState(),
        onCopy: { _ in },
        onCopyMerged: { _ in },
        onCopyText: { _ in },
        onCopyPlainText: { _ in },
        onCopySnippet: { _ in }
    )
    .environment(manager)
    .environment(snippets)
    .environment(TranslationService())
    .padding(30)
    .background(Color(nsColor: .windowBackgroundColor))
}
#endif
