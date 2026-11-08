//
//  ItemRowView.swift
//  HaoPaste
//
//  One clipboard history card with hover actions and quick-copy affordance.
//

import AppKit
import SwiftUI

struct ItemRowView: View {
    let item: ClipboardItem
    let index: Int
    let thumbnailURL: URL?
    let imageURL: URL?
    let dragProvider: () -> NSItemProvider
    let isSelected: Bool
    let isMultiSelected: Bool
    let onRowClick: () -> Void
    let onCopy: () -> Void
    let onCopyText: (String) -> Void
    let onPreview: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let iconSize: CGFloat = 32

    @ViewBuilder
    var body: some View {
        if canDragOut {
            rowContent
                .onDrag(dragProvider)
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
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
            Button {
                onPreview()
            } label: {
                Label("预览", systemImage: "eye")
            }

            Divider()

            if item.type == .url, let url = URL(string: item.content) {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Label("打开链接", systemImage: "safari")
                }

                Button {
                    copyMarkdownLink(for: url)
                } label: {
                    Label("复制为 Markdown 链接", systemImage: "doc.on.doc")
                }

                Divider()
            }

            if item.type == .file {
                Button {
                    openFiles()
                } label: {
                    Label("打开", systemImage: "arrow.up.forward.app")
                }
                .disabled(item.availableFileURLs.isEmpty)

                Button {
                    revealFiles()
                } label: {
                    Label("在 Finder 中显示", systemImage: "folder")
                }
                .disabled(item.availableFileURLs.isEmpty)

                Divider()
            }

            if item.type == .image, imageURL != nil {
                Button {
                    saveImage()
                } label: {
                    Label("保存图片…", systemImage: "square.and.arrow.down")
                }

                Divider()
            }

            if item.type == .colorHex, let color = HexColor(hex: item.content) {
                Button {
                    onCopyText(color.normalizedHex)
                } label: {
                    Label("复制 HEX（\(color.normalizedHex)）", systemImage: "paintpalette")
                }

                Button {
                    onCopyText(color.rgbString)
                } label: {
                    Label("复制 RGB（\(color.rgbString)）", systemImage: "paintpalette")
                }

                Button {
                    onCopyText(color.hslString)
                } label: {
                    Label("复制 HSL（\(color.hslString)）", systemImage: "paintpalette")
                }

                Divider()
            }

            if item.hasRichText {
                Button {
                    onCopyText(item.content)
                } label: {
                    Label("复制为纯文本", systemImage: "doc.plaintext")
                }

                Divider()
            }

            Button("复制", action: onCopy)

            Button(item.isPinned ? "取消置顶" : "置顶", action: onTogglePin)

            Divider()

            Button("删除", role: .destructive, action: onDelete)
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Main content

    private var copyButton: some View {
        Button(action: onRowClick) {
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
        .help("点击复制；按住 ⌘ 或 ⇧ 可多选")
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("复制到剪切板；按住 Command 或 Shift 可多选")
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
            if isMultiSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.accentColor)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }

            if item.type == .colorHex, let color = HexColor(hex: item.content) {
                Circle()
                    .fill(color.color)
                    .frame(width: 13, height: 13)
                    .overlay {
                        Circle()
                            .strokeBorder(Color.primary.opacity(0.14), lineWidth: 0.5)
                    }
                    .help(color.normalizedHex)
            }

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

            if item.type == .file, item.hasMissingFiles {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.orange)
                    .help(
                        item.hasAvailableFiles
                            ? "部分文件已丢失，将复制可用文件"
                            : "文件已丢失，无法复制"
                    )
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
                    symbolName: "eye",
                    help: "预览（⌘Y）",
                    action: onPreview
                )

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
        .frame(width: 76, height: 26, alignment: .trailing)
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

    // MARK: - Row Actions

    private func copyMarkdownLink(for url: URL) {
        let title = url.host ?? item.displayTitle
        onCopyText("[\(title)](\(item.content))")
    }

    private func openFiles() {
        for url in item.availableFileURLs {
            NSWorkspace.shared.open(url)
        }
    }

    private func revealFiles() {
        let urls = item.availableFileURLs
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    private func saveImage() {
        guard let imageURL else { return }
        ImageSavePanel.present(imageURL: imageURL)
    }

    private var canDragOut: Bool {
        switch item.type {
        case .image:
            return imageURL != nil
        case .file:
            return item.availableFileURLs.count == 1
        case .text, .code, .url, .colorHex:
            return true
        }
    }

    private var accessibilityDescription: String {
        var parts = [item.formatBadge, item.displayTitle]
        if item.isPinned {
            parts.append("已置顶")
        }
        if item.hasRichText {
            parts.append("富文本")
        }
        if isMultiSelected {
            parts.append("已多选")
        }
        if let sourceApp = item.sourceApp {
            parts.append("来自 \(sourceApp.name)")
        }
        parts.append(RelativeTime.string(from: item.createdAt))
        return parts.joined(separator: "，")
    }
}
