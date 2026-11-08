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

                Text(isPaused ? "监听已暂停" : "监听中")

                Text("·")
                    .foregroundStyle(.quaternary)

                Text("\(itemCount) \(itemLabel)")
                    .contentTransition(.numericText())
            }

            Spacer(minLength: 10)

            HStack(spacing: 10) {
                FooterShortcutHint(keys: "↑↓", label: "选择")
                FooterShortcutHint(keys: "↵", label: "复制")
                FooterShortcutHint(keys: "⌘1–9", label: "快速复制")
                FooterShortcutHint(keys: "esc", label: isSearching ? "清除" : "关闭")
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
