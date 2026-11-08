//
//  PreviewOverlayView.swift
//  HaoPaste
//
//  Quick preview card for images, text, colors and files.
//

import AppKit
import SwiftUI

struct PreviewOverlayView: View {
    let item: ClipboardItem
    let imageURL: URL?
    let richText: RichTextPayload?
    let onClose: () -> Void
    let onCopy: () -> Void
    let onCopyText: (String) -> Void
    let onOpenURL: (URL) -> Void
    let onOpenFiles: () -> Void
    let onRevealFiles: () -> Void
    let onSaveImage: () -> Void
    let onTranslate: () -> Void
    let onExtractText: () -> Void
    let onExtractAndTranslate: () -> Void
    var showsScrim = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPresented = false

    var body: some View {
        ZStack {
            if showsScrim {
                Color.black.opacity(0.30)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onClose()
                    }
            }

            card
                .scaleEffect(isPresented ? 1 : 0.96)
                .opacity(isPresented ? 1 : 0)
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : Theme.spring) {
                isPresented = true
            }
        }
    }

    // MARK: - Card

    private var card: some View {
        VStack(spacing: 0) {
            header

            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: Theme.hairline)

            bodyContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: Theme.hairline)

            footer
        }
        .frame(width: 620, height: 452)
        .background(.regularMaterial)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: Theme.hairline)
        }
        .shadow(color: Color.black.opacity(0.28), radius: 24, x: 0, y: 10)
        .shadow(color: Color.black.opacity(0.10), radius: 4, x: 0, y: 1)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: item.type.symbolName)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)
                .frame(width: 30, height: 30)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.accentColor.opacity(0.11))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: Theme.hairline)
                }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(item.displayTitle)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.accentColor)
                    }
                }

                Text("\(item.formatBadge) · \(item.detailBadge)")
                    .font(.system(size: 10.5, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 10)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background {
                        Circle()
                            .fill(Color.primary.opacity(0.055))
                    }
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help("关闭预览（esc）")
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
    }

    // MARK: - Body

    @ViewBuilder
    private var bodyContent: some View {
        if item.type == .image, let imageURL {
            imagePreview(url: imageURL)
        } else if item.type == .colorHex, let color = HexColor(hex: item.content) {
            colorPreview(color)
        } else if item.type == .file {
            filePreview
        } else {
            textPreview
        }
    }

    private func imagePreview(url: URL) -> some View {
        ZStack {
            PreviewCheckerboard()

            PreviewImageView(url: url)
        }
        .onDrag {
            ItemDragProvider.make(
                for: item,
                imageURL: url,
                richText: richText
            )
        }
        .help("拖拽图片到其他应用")
    }

    private var textPreview: some View {
        let preview = ItemPreviewBuilder.text(for: item, richText: richText)

        return ScrollView(.vertical) {
            Text(AttributedString(preview.attributedString))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
        }
        .scrollIndicators(.never)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.025))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Theme.hairlineColor, lineWidth: Theme.hairline)
        }
        .overlay(alignment: .bottomTrailing) {
            if preview.isTruncated {
                Text("仅显示前 \(ItemPreviewBuilder.maxPreviewCharacters.formatted()) 个字符")
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .frame(height: 20)
                    .background {
                        Capsule()
                            .fill(.regularMaterial)
                    }
                    .overlay {
                        Capsule()
                            .strokeBorder(Theme.hairlineColor, lineWidth: Theme.hairline)
                    }
                    .padding(12)
            }
        }
        .padding(14)
    }

    private func colorPreview(_ color: HexColor) -> some View {
        VStack(spacing: 13) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color.color)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.10), lineWidth: Theme.hairline)
                }
                .shadow(color: color.color.opacity(0.28), radius: 14, x: 0, y: 6)

            HStack(spacing: 10) {
                colorValue(color.normalizedHex)
                colorValue(color.rgbString)
                colorValue(color.hslString)
            }
        }
        .padding(18)
    }

    private func colorValue(_ value: String) -> some View {
        Text(value)
            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background {
                Capsule()
                    .fill(Color.primary.opacity(0.045))
            }
    }

    private var filePreview: some View {
        ScrollView(.vertical) {
            VStack(spacing: 5) {
                ForEach(Array(fileEntries.enumerated()), id: \.offset) { _, entry in
                    fileRow(url: entry.url, isMissing: entry.isMissing)
                }
            }
            .padding(14)
        }
        .scrollIndicators(.never)
    }

    @ViewBuilder
    private func fileRow(url: URL, isMissing: Bool) -> some View {
        if isMissing {
            fileRowContent(url: url, isMissing: true)
        } else {
            fileRowContent(url: url, isMissing: false)
                .onDrag {
                    NSItemProvider(contentsOf: url)
                        ?? ItemDragProvider.textProvider(url.path)
                }
                .onTapGesture(count: 2) {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
                .help("拖拽到其他应用，双击在 Finder 中显示")
        }
    }

    private func fileRowContent(url: URL, isMissing: Bool) -> some View {
        HStack(spacing: 10) {
            if isMissing {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.orange)
                    .frame(width: 24, height: 24)
            } else {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .frame(width: 24, height: 24)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(url.lastPathComponent)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(url.deletingLastPathComponent().path)
                    .font(.system(size: 9.5, weight: .regular, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            Text(isMissing ? "已丢失" : "拖拽")
                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                .foregroundStyle(isMissing ? Color.orange : Color.secondary)
                .padding(.horizontal, 6)
                .frame(height: 17)
                .background {
                    Capsule()
                        .fill(Color.primary.opacity(0.05))
                }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.028))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Theme.hairlineColor, lineWidth: Theme.hairline)
        }
    }

    private var fileEntries: [(url: URL, isMissing: Bool)] {
        (item.filePaths ?? []).map { path in
            let url = URL(fileURLWithPath: path)
            return (url, !FileManager.default.fileExists(atPath: path))
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 8) {
            Text(footerMeta)
                .font(.system(size: 10.5, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 10)

            HStack(spacing: 7) {
                if item.isTranslatable {
                    secondaryButton("翻译", systemImage: "character.bubble") {
                        onTranslate()
                    }
                }

                if item.type == .image, imageURL != nil {
                    secondaryButton(
                        "提取文字",
                        systemImage: "text.viewfinder",
                        action: onExtractText
                    )
                    secondaryButton(
                        "识图并翻译",
                        systemImage: "character.bubble",
                        action: onExtractAndTranslate
                    )
                    secondaryButton(
                        "保存…",
                        systemImage: "square.and.arrow.down",
                        action: onSaveImage
                    )
                }

                if item.type == .file {
                    secondaryButton(
                        "打开",
                        systemImage: "arrow.up.forward.app",
                        isEnabled: !item.availableFileURLs.isEmpty,
                        action: onOpenFiles
                    )
                    secondaryButton(
                        "Finder",
                        systemImage: "folder",
                        isEnabled: !item.availableFileURLs.isEmpty,
                        action: onRevealFiles
                    )
                }

                if item.type == .url, let url = URL(string: item.content) {
                    secondaryButton("打开", systemImage: "safari") {
                        onOpenURL(url)
                    }
                }

                if item.hasRichText {
                    secondaryButton("纯文本", systemImage: "doc.plaintext") {
                        onCopyText(item.content)
                    }
                }

                primaryCopyButton
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
    }

    private var footerMeta: String {
        var parts: [String] = []

        if let sourceApp = item.sourceApp, !sourceApp.name.isEmpty {
            parts.append("来自 \(sourceApp.name)")
        }
        parts.append(RelativeTime.string(from: item.createdAt))

        return parts.joined(separator: " · ")
    }

    private var primaryCopyButton: some View {
        Button(action: onCopy) {
            HStack(spacing: 5) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                Text("复制")
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 12)
            .frame(height: 27)
            .background {
                Capsule()
                    .fill(Color.accentColor)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help("复制并关闭（↵）")
    }

    private func secondaryButton(
        _ title: String,
        systemImage: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                Text(title)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
            }
            .foregroundStyle(isEnabled ? Color.primary : Color.secondary)
            .padding(.horizontal, 9)
            .frame(height: 27)
            .background {
                Capsule()
                    .fill(Color.primary.opacity(isEnabled ? 0.06 : 0.03))
            }
            .overlay {
                Capsule()
                    .strokeBorder(Theme.hairlineColor, lineWidth: Theme.hairline)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .disabled(!isEnabled)
        .help(title)
    }
}

// MARK: - Image helpers

private struct PreviewImageView: View {
    let url: URL

    @State private var image: NSImage?
    @State private var didFail = false

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else if didFail {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)

                    Text("无法读取图片")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(14)
        .task(id: url) {
            let loaded = NSImage(contentsOf: url)
            image = loaded
            didFail = loaded == nil
        }
    }
}

private struct PreviewCheckerboard: View {
    private let tile: CGFloat = 12

    var body: some View {
        Canvas { context, size in
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Color.primary.opacity(0.018))
            )

            var row = 0
            var y: CGFloat = 0
            while y < size.height {
                var column = 0
                var x: CGFloat = 0

                while x < size.width {
                    if (row + column).isMultiple(of: 2) {
                        context.fill(
                            Path(CGRect(x: x, y: y, width: tile, height: tile)),
                            with: .color(Color.primary.opacity(0.032))
                        )
                    }

                    column += 1
                    x += tile
                }

                row += 1
                y += tile
            }
        }
    }
}
