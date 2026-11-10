//
//  PanelFooterView.swift
//  HaoPaste
//
//  Monitoring status and keyboard hints.
//

import SwiftUI

struct PanelFooterView: View {
    let isPaused: Bool
    let itemCount: Int
    let itemLabel: String
    let isSearching: Bool

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(isPaused ? Color.secondary.opacity(0.45) : Color.accentColor)
                    .frame(width: 5, height: 5)

                Text(isPaused ? L("监听已暂停") : L("监听中"))

                Text("·")
                    .foregroundStyle(.quaternary)

                Text(L(itemLabel, itemCount))
                    .contentTransition(.numericText())
            }

            Spacer(minLength: 10)

            HStack(spacing: 10) {
                FooterShortcutHint(keys: "↑↓", label: L("选择"))
                FooterShortcutHint(keys: "↵", label: L("复制"))
                FooterShortcutHint(keys: "⌘1–9", label: L("快速复制"))
                FooterShortcutHint(keys: "⌘T", label: L("翻译"))
                FooterShortcutHint(keys: "⌘Y", label: L("预览"))
                FooterShortcutHint(keys: "esc", label: isSearching ? L("清除") : L("关闭"))
            }
        }
        .font(.system(size: 10, weight: .medium, design: .rounded))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 18)
        .frame(height: 31)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: Theme.hairline)
        }
        .accessibilityElement(children: .combine)
    }
}
