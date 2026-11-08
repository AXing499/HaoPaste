//
//  ContentView.swift
//  HaoPaste
//
//  The floating clipboard panel: search, category pills and history list.
//

import SwiftUI

struct ContentView: View {
    @Environment(ClipboardManager.self) private var manager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Bindable var state: PanelViewState
    let onCopy: (ClipboardItem) -> Void
    let onCopyText: (String) -> Void

    @FocusState private var isSearchFocused: Bool

    private var visibleItems: [ClipboardItem] {
        manager.filteredItems(query: state.searchText, filter: state.filter)
    }

    private var visibleIDs: [UUID] {
        visibleItems.map(\.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            historyList
            PanelFooterView(
                isPaused: manager.isMonitoringPaused,
                itemCount: manager.items.count,
                isSearching: state.isSearching
            )
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
            state.ensureSelection(in: visibleItems)
            isSearchFocused = true
        }
        .onChange(of: state.focusToken) { _, _ in
            isSearchFocused = true
        }
        .onChange(of: state.searchText) { _, _ in
            state.ensureSelection(in: visibleItems)
        }
        .onChange(of: state.filter) { _, _ in
            state.ensureSelection(in: visibleItems)
        }
        .onChange(of: visibleIDs) { _, _ in
            state.ensureSelection(in: visibleItems)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            searchBar

            HStack(spacing: 10) {
                FilterTabsView(selection: $state.filter)

                Spacer(minLength: 8)

                Text("\(visibleItems.count) 条")
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .contentTransition(.numericText())
                    .animation(reduceMotion ? nil : Theme.spring, value: visibleItems.count)
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

            TextField("搜索剪切板历史…", text: $state.searchText)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .rounded))
                .focusEffectDisabled()
                .focused($isSearchFocused)
                .help("支持中文、拼音缩写、来源应用与模糊匹配")
                .onSubmit {
                    copySelectedItem()
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
                            isSelected: state.selectedID == item.id,
                            onCopy: {
                                onCopy(item)
                            },
                            onCopyText: onCopyText,
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
    ContentView(
        state: PanelViewState(),
        onCopy: { _ in },
        onCopyText: { _ in }
    )
    .environment(manager)
        .padding(30)
        .background(Color(nsColor: .windowBackgroundColor))
}
#endif
