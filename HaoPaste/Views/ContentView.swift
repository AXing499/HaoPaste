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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Bindable var state: PanelViewState
    let onCopy: (ClipboardItem) -> Void
    let onCopyText: (String) -> Void
    let onCopySnippet: (Snippet) -> Void

    @FocusState private var isSearchFocused: Bool

    private var isSnippetMode: Bool {
        state.filter == .snippets
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

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header
                contentList
                PanelFooterView(
                    isPaused: manager.isMonitoringPaused,
                    itemCount: isSnippetMode ? snippetManager.snippets.count : manager.items.count,
                    itemLabel: isSnippetMode ? "个片段" : "条记录",
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
                    }
                )
                .zIndex(1)
                .transition(.opacity)
            }
        }
        .frame(width: Theme.panelSize.width, height: Theme.panelSize.height)
        .background {
            panelBackground
        }
        .clipShape(Theme.panelShape)
        .hairlineStroke(Theme.panelShape)
        .shadow(color: Color.black.opacity(0.20), radius: 14, x: 0, y: 5)
        .shadow(color: Color.black.opacity(0.06), radius: 2, x: 0, y: 1)
        .padding(Theme.windowPadding)
        .onAppear {
            ensureSelectionForCurrentMode()
            isSearchFocused = true
        }
        .onChange(of: state.focusToken) { _, _ in
            isSearchFocused = true
        }
        .onChange(of: state.searchText) { _, _ in
            state.endPreview()
            ensureSelectionForCurrentMode()
        }
        .onChange(of: state.filter) { _, _ in
            state.endPreview()
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

                Text(
                    isSnippetMode
                        ? "\(visibleSnippets.count) 个片段"
                        : "\(visibleItems.count) 条"
                )
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
                .contentTransition(.numericText())
                .animation(
                    reduceMotion ? nil : Theme.spring,
                    value: isSnippetMode ? visibleSnippets.count : visibleItems.count
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
                isSnippetMode ? "搜索片段…" : "搜索剪切板历史…",
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
                            isSelected: state.selectedID == item.id,
                            onCopy: {
                                onCopy(item)
                            },
                            onCopyText: onCopyText,
                            onPreview: {
                                state.beginPreview(item)
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
                .padding(.bottom, 6)
                .animation(reduceMotion ? nil : Theme.gentleSpring, value: visibleIDs)
            }
            .scrollIndicators(.never)
            .overlay {
                if visibleItems.isEmpty {
                    EmptyStateView(query: state.searchText, filter: state.filter)
                }
            }
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
        } else {
            state.ensureSelection(in: visibleItems)
        }
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

#if DEBUG
#Preview("HaoPaste Panel") {
    let manager = ClipboardManager()
    let snippets = SnippetManager()
    ContentView(
        state: PanelViewState(),
        onCopy: { _ in },
        onCopyText: { _ in },
        onCopySnippet: { _ in }
    )
    .environment(manager)
    .environment(snippets)
    .padding(30)
    .background(Color(nsColor: .windowBackgroundColor))
}
#endif
