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
        isFiltering ? "没有找到匹配内容" : "暂无剪切板记录"
    }

    private var subtitle: String {
        if isFiltering {
            return "换个关键词，或试试其他分类。"
        }
        return "复制任意文本、代码、链接或图片，\n它们会安全地出现在这里。"
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
