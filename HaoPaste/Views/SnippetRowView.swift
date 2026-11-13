//
//  SnippetRowView.swift
//  HaoPaste
//
//  One reusable snippet card in the panel's snippet tab.
//

import SwiftUI

struct SnippetRowView: View {
    let snippet: Snippet
    let index: Int
    let isSelected: Bool
    let onCopy: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let iconSize: CGFloat = 32

    var body: some View {
        Button(action: onCopy) {
            HStack(spacing: 11) {
                Image(systemName: "text.quote")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: iconSize, height: iconSize)
                    .background {
                        RoundedRectangle(
                            cornerRadius: Theme.iconCornerRadius,
                            style: .continuous
                        )
                        .fill(Color.accentColor.opacity(0.10))
                    }
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: Theme.iconCornerRadius,
                            style: .continuous
                        )
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: Theme.hairline)
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(snippet.title)
                        .font(.system(.body, design: .rounded).weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(snippet.contentPreview)
                        .font(.system(size: 10.5, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 10)

                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        badge(L("片段条目"))
                        badge(L("%d 字符", snippet.characterCount))
                    }

                    Text(RelativeTime.string(from: snippet.updatedAt))
                        .font(.system(size: 10, weight: .regular, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
                .fixedSize(horizontal: true, vertical: false)

                if index < 9 {
                    KeyboardShortcutBadge(
                        text: "⌘\(index + 1)",
                        emphasized: isSelected
                    )
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, 10)
            .padding(.vertical, 8)
            .frame(minHeight: 60)
            .contentShape(Theme.cardShape)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .pointingHandCursor()
        .background {
            ZStack {
                GeometryReader { proxy in
                    GlassSurfaceBackground(
                        cornerRadius: 40,
                        fallback: .material
                    )
                    .frame(
                        width: proxy.size.width + 48,
                        height: max(96, proxy.size.height + 32)
                    )
                    .position(
                        x: proxy.size.width / 2,
                        y: proxy.size.height / 2
                    )
                }

                Theme.cardShape
                    .fill(backgroundColor)
            }
            .clipShape(Theme.cardShape)
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
        .onHover { hovering in
            isHovering = hovering
        }
        .animation(reduceMotion ? nil : Theme.spring, value: isHovering)
        .animation(reduceMotion ? nil : Theme.spring, value: isSelected)
        .contextMenu {
            Button(L("复制片段"), action: onCopy)

            Divider()

            Button(L("编辑片段…"), action: onEdit)
            Button(L("删除片段…"), role: .destructive, action: onDelete)
        }
        .help(L("点击复制片段"))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            L(
                "片段，%@，%d 字符",
                snippet.title,
                snippet.characterCount
            )
        )
        .accessibilityHint(L("复制片段内容到剪贴板"))
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
}
