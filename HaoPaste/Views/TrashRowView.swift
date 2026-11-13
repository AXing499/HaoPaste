//
//  TrashRowView.swift
//  HaoPaste
//
//  One recoverable entry in the panel's Recently Deleted tab.
//

import SwiftUI

struct TrashRowView: View {
    let entry: TrashedClipboardItem
    let retentionDays: Int
    let onRestore: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let iconSize: CGFloat = 32

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: entry.item.type.symbolName)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.secondary)
                .frame(width: iconSize, height: iconSize)
                .background {
                    RoundedRectangle(
                        cornerRadius: Theme.iconCornerRadius,
                        style: .continuous
                    )
                    .fill(Color.primary.opacity(0.05))
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.item.displayTitle)
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(previewText)
                    .font(.system(size: 10.5, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 10)

            VStack(alignment: .trailing, spacing: 4) {
                Text(
                    L(
                        "%@删除",
                        RelativeTime.string(from: entry.deletedAt)
                    )
                )
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundStyle(.tertiary)

                Text(expiryText)
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: true, vertical: false)

            Button {
                onRestore()
            } label: {
                Text(L("恢复"))
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 10)
                    .frame(height: 24)
                    .background {
                        Capsule()
                            .fill(Color.accentColor.opacity(0.10))
                    }
            }
            .buttonStyle(.plain)
            .pointingHandCursor()
            .help(L("恢复到剪贴板历史"))

            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .pointingHandCursor()
            .help(L("彻底删除"))
        }
        .padding(.leading, 10)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .frame(minHeight: 60)
        .background {
            ZStack {
                GeometryReader { proxy in
                    GlassSurfaceBackground(
                        cornerRadius: 40,
                        fallback: .material
                    )
                    .frame(
                        width: proxy.size.width,
                        height: max(96, proxy.size.height)
                    )
                    .position(
                        x: proxy.size.width / 2,
                        y: proxy.size.height / 2
                    )
                }

                Theme.cardShape
                    .fill(
                        Color.primary.opacity(isHovering ? 0.055 : 0.03)
                    )
            }
            .clipShape(Theme.cardShape)
        }
        .overlay {
            Theme.cardShape
                .strokeBorder(Theme.hairlineColor, lineWidth: Theme.hairline)
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .animation(reduceMotion ? nil : Theme.spring, value: isHovering)
        .contextMenu {
            Button(L("恢复"), action: onRestore)
            Button(L("彻底删除…"), role: .destructive, action: onDelete)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            L(
                "最近删除，%@，%@",
                entry.item.displayTitle,
                expiryText
            )
        )
    }

    private var previewText: String {
        let preview = entry.item.shelfSnippet
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return preview.isEmpty ? entry.item.formatBadge : preview
    }

    private var expiryText: String {
        let expiry = entry.deletedAt.addingTimeInterval(
            Double(max(1, retentionDays)) * 24 * 60 * 60
        )
        let seconds = expiry.timeIntervalSinceNow
        guard seconds > 0 else { return L("即将自动清除") }
        let days = max(1, Int(ceil(seconds / (24 * 60 * 60))))
        return L("%d 天后清除", days)
    }
}
