//
//  EmptyStateView.swift
//  HaoPaste
//
//  Friendly zero-state for an empty history or an empty search result.
//

import SwiftUI

struct EmptyStateView: View {
    let query: String
    let filter: ClipboardFilter

    private var isFiltering: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || filter != .all
    }

    private var title: String {
        isFiltering ? L("没有找到匹配内容") : L("暂无剪切板记录")
    }

    private var subtitle: String {
        if isFiltering {
            return L("换个关键词，或试试其他分类。")
        }
        return L("复制任意文本、代码、链接、图片或文件，\n它们会安全地出现在这里。")
    }

    private var symbolName: String {
        isFiltering ? "magnifyingglass" : "clipboard"
    }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.04))
                    .frame(width: 64, height: 64)

                Image(systemName: symbolName)
                    .font(.system(size: 23, weight: .light, design: .rounded))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 4) {
                Text(title)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
        .accessibilityElement(children: .combine)
    }
}

struct SnippetEmptyStateView: View {
    let query: String

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.04))
                    .frame(width: 64, height: 64)

                Image(systemName: isSearching ? "magnifyingglass" : "text.quote")
                    .font(.system(size: 23, weight: .light, design: .rounded))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 4) {
                Text(isSearching ? L("没有找到匹配片段") : L("还没有片段"))
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(.primary)

                Text(
                    isSearching
                        ? L("换个关键词再试试。")
                        : L("在 设置 → 片段 中创建常用文本，\n之后可在这里一键复制。")
                )
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
        .accessibilityElement(children: .combine)
    }
}

struct TrashEmptyStateView: View {
    let query: String
    let retentionDays: Int

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.04))
                    .frame(width: 64, height: 64)

                Image(systemName: isSearching ? "magnifyingglass" : "trash")
                    .font(.system(size: 23, weight: .light, design: .rounded))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 4) {
                Text(isSearching ? L("没有找到匹配内容") : L("最近删除为空"))
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(.primary)

                Text(
                    isSearching
                        ? L("换个关键词试试。")
                        : L(
                            "删除的记录会在这里保留 %d 天，之后自动清除。",
                            retentionDays
                        )
                )
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
        .accessibilityElement(children: .combine)
    }
}
