//
//  ItemRowView.swift
//  HaoPaste
//
//  One clipboard history card with hover actions and quick-copy affordance.
//

import SwiftUI

struct ItemRowView: View {
    let item: ClipboardItem
    let index: Int
    let thumbnailURL: URL?
    let isSelected: Bool
    let onCopy: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let iconSize: CGFloat = 32

    var body: some View {
        HStack(spacing: 8) {
            copyButton
            actionCluster
        }
        .padding(.leading, 10)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .frame(minHeight: 60)
        .background {
            Theme.cardShape
                .fill(backgroundColor)
        }
        .overlay {
            Theme.cardShape
                .strokeBorder(borderColor, lineWidth: Theme.hairline)
        }
        .shadow(
            color: Color.black.opacity(isHovering && !isSelected ? 0.07 : 0),
            radius: 9,
            x: 0,
            y: 4
        )
        .offset(y: isHovering && !isSelected && !reduceMotion ? -1 : 0)
        .contentShape(Theme.cardShape)
        .onHover { hovering in
            isHovering = hovering
        }
        .animation(reduceMotion ? nil : Theme.spring, value: isHovering)
        .animation(reduceMotion ? nil : Theme.spring, value: isSelected)
        .animation(reduceMotion ? nil : Theme.quickSpring, value: item.isPinned)
        .contextMenu {
            Button("复制", action: onCopy)

            Button(item.isPinned ? "取消置顶" : "置顶", action: onTogglePin)

            Divider()

            Button("删除", role: .destructive, action: onDelete)
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Main content

    private var copyButton: some View {
        Button(action: onCopy) {
            HStack(spacing: 11) {
                typeIcon

                VStack(alignment: .leading, spacing: 3) {
                    titleLine
                    sourceLine
                }

                Spacer(minLength: 10)

                infoCluster
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help("点击复制")
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("复制到剪切板")
    }

    @ViewBuilder
    private var typeIcon: some View {
        if item.type == .image, let thumbnailURL {
            ImageThumbnailView(url: thumbnailURL, size: iconSize)
                .scaleEffect(isHovering ? 1.03 : 1)
                .animation(reduceMotion ? nil : Theme.spring, value: isHovering)
        } else {
            Image(systemName: item.type.symbolName)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)
                .frame(width: iconSize, height: iconSize)
                .background {
                    RoundedRectangle(cornerRadius: Theme.iconCornerRadius, style: .continuous)
                        .fill(Color.accentColor.opacity(0.10))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.iconCornerRadius, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: Theme.hairline)
                }
                .scaleEffect(isHovering ? 1.03 : 1)
                .animation(reduceMotion ? nil : Theme.spring, value: isHovering)
        }
    }

    private var titleLine: some View {
        HStack(spacing: 5) {
            Text(item.displayTitle)
                .font(.system(.body, design: .rounded).weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.accentColor)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
    }

    private var sourceLine: some View {
        Text(sourceLabel)
            .font(.system(size: 10.5, weight: .regular, design: .rounded))
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    private var sourceLabel: String {
        if let sourceApp = item.sourceApp, !sourceApp.name.isEmpty {
            return "来自 \(sourceApp.name)"
        }
        return "剪切板"
    }

    // MARK: - Trailing information

    private var infoCluster: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 4) {
                badge(item.formatBadge)
                badge(item.detailBadge)
            }

            Text(RelativeTime.string(from: item.createdAt))
                .font(.system(size: 10, weight: .regular, design: .rounded))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
            .foregroundStyle(isSelected ? Color.accentColor.opacity(0.92) : Color.secondary)
            .padding(.horizontal, 6)
            .frame(height: 17)
            .background {
                Capsule()
                    .fill(
                        isSelected
                            ? Color.accentColor.opacity(0.09)
                            : Color.primary.opacity(0.05)
                    )
            }
            .overlay {
                Capsule()
                    .strokeBorder(
                        isSelected
                            ? Color.accentColor.opacity(0.16)
                            : Color.primary.opacity(0.06),
                        lineWidth: Theme.hairline
                    )
            }
    }

    // MARK: - Hover actions

    private var actionCluster: some View {
        ZStack(alignment: .trailing) {
            if index < 9 {
                Button(action: onCopy) {
                    KeyboardShortcutBadge(
                        text: "⌘\(index + 1)",
                        emphasized: isSelected
                    )
                }
                .buttonStyle(.plain)
                .focusable(false)
                .help("快速复制")
                .opacity(isHovering ? 0 : 1)
                .scaleEffect(isHovering ? 0.92 : 1)
                .allowsHitTesting(!isHovering)
            }

            HStack(spacing: 2) {
                RoundIconButton(
                    symbolName: item.isPinned ? "pin.slash" : "pin",
                    help: item.isPinned ? "取消置顶" : "置顶",
                    action: onTogglePin
                )

                RoundIconButton(
                    symbolName: "trash",
                    help: "删除",
                    action: onDelete
                )
            }
            .opacity(isHovering ? 1 : 0)
            .scaleEffect(isHovering ? 1 : 0.9)
            .allowsHitTesting(isHovering)
        }
        .frame(width: 52, height: 26, alignment: .trailing)
        .animation(reduceMotion ? nil : Theme.spring, value: isHovering)
    }

    // MARK: - Styling

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(isHovering ? 0.14 : 0.11)
        }
        if isHovering {
            return Color.primary.opacity(0.055)
        }
        return Color.primary.opacity(0.025)
    }

    private var borderColor: Color {
        isSelected ? Color.accentColor.opacity(0.28) : Theme.hairlineColor
    }

    private var accessibilityDescription: String {
        var parts = [item.formatBadge, item.displayTitle]
        if item.isPinned {
            parts.append("已置顶")
        }
        if let sourceApp = item.sourceApp {
            parts.append("来自 \(sourceApp.name)")
        }
        parts.append(RelativeTime.string(from: item.createdAt))
        return parts.joined(separator: "，")
    }
}
