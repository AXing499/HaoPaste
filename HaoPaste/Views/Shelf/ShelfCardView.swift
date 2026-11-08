//
//  ShelfCardView.swift
//  HaoPaste
//
//  One clipboard card clipped to the shelf line.
//

import AppKit
import SwiftUI

struct ShelfCardView: View {
    let item: ClipboardItem
    let cardWidth: CGFloat
    let thumbnailURL: URL?
    let imageURL: URL?
    let isHovering: Bool
    let isCopied: Bool
    let cardHeight: CGFloat
    let baseAngle: Double
    let edge: ClipboardShelfEdge
    let canDragOut: Bool
    let dragProvider: () -> NSItemProvider
    let onCopy: () -> Void
    let onCopyText: (String) -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void
    let onPreview: () -> Void
    let onTranslate: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let bodyOffset = ClipboardShelfLayout.bodyOffset

    private var bodyHeight: CGFloat {
        cardHeight - Self.bodyOffset
    }

    private var bodyShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 11, style: .continuous)
    }

    private var rotationAnchor: UnitPoint {
        switch edge {
        case .top: return .top
        case .left: return .topLeading
        case .right: return .topTrailing
        }
    }

    private var clipAlignment: Alignment {
        switch edge {
        case .top: return .top
        case .left: return .topLeading
        case .right: return .topTrailing
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            bodySurface
                .contentShape(Rectangle())
                .onTapGesture(perform: onCopy)

            ShelfClipView(
                isPinned: item.isPinned,
                isHovering: isHovering,
                onDelete: onDelete
            )
            .frame(maxWidth: .infinity, alignment: clipAlignment)

            if isHovering {
                actionBar
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
            }
        }
        .frame(
            width: cardWidth,
            height: ClipboardShelfLayout.cardHeight,
            alignment: .top
        )
        .rotationEffect(
            .degrees(isHovering || reduceMotion ? 0 : baseAngle),
            anchor: rotationAnchor
        )
        .offset(
            x: isHovering && !reduceMotion
                ? ClipboardShelfLayout.hoverOffset(for: edge).width
                : 0,
            y: isHovering && !reduceMotion
                ? ClipboardShelfLayout.hoverOffset(for: edge).height
                : 0
        )
        .scaleEffect(
            isHovering && !reduceMotion ? 1.035 : 1,
            anchor: rotationAnchor
        )
        .animation(reduceMotion ? nil : Theme.spring, value: isHovering)
        .help("点击复制")
        .accessibilityLabel("\(item.formatBadge)，\(item.displayTitle)")
        .accessibilityHint("复制到剪贴板")
        .contextMenu {
            Button {
                onPreview()
            } label: {
                Label("预览", systemImage: "eye")
            }

            Button {
                onCopy()
            } label: {
                Label("复制", systemImage: "doc.on.doc")
            }

            if item.isTranslatable {
                Button {
                    onTranslate()
                } label: {
                    Label("翻译…", systemImage: "translate")
                }
            } else if item.type == .image, imageURL != nil {
                Button {
                    onTranslate()
                } label: {
                    Label("识图并翻译", systemImage: "text.viewfinder")
                }
            }

            Button {
                onTogglePin()
            } label: {
                Label(
                    item.isPinned ? "取消置顶" : "置顶",
                    systemImage: item.isPinned ? "pin.slash" : "pin"
                )
            }

            if item.hasRichText {
                Button {
                    onCopyText(item.plainText)
                } label: {
                    Label("复制纯文本", systemImage: "textformat")
                }
            }

            if item.type == .url, let url = URL(string: item.content) {
                Divider()

                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Label("打开链接", systemImage: "safari")
                }

                Button {
                    let title = url.host ?? item.displayTitle
                    onCopyText("[\(title)](\(item.content))")
                } label: {
                    Label("复制为 Markdown 链接", systemImage: "doc.on.doc")
                }
            }

            if item.type == .file {
                Divider()

                Button {
                    for url in item.availableFileURLs {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("打开文件", systemImage: "arrow.up.forward.app")
                }
                .disabled(item.availableFileURLs.isEmpty)

                Button {
                    NSWorkspace.shared.activateFileViewerSelecting(
                        item.availableFileURLs
                    )
                } label: {
                    Label("在 Finder 中显示", systemImage: "folder")
                }
                .disabled(item.availableFileURLs.isEmpty)
            }

            if item.type == .image, imageURL != nil {
                Divider()

                Button {
                    if let imageURL {
                        ImageSavePanel.present(imageURL: imageURL)
                    }
                } label: {
                    Label("保存图片…", systemImage: "square.and.arrow.down")
                }
            }

            if item.type == .colorHex, let color = HexColor(hex: item.content) {
                Divider()

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
            }

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private var bodySurface: some View {
        let surface = bodyContent
            .frame(width: cardWidth, height: bodyHeight)
            .offset(y: Self.bodyOffset)

        if canDragOut {
            surface.onDrag(dragProvider)
        } else {
            surface
        }
    }

    private var actionBar: some View {
        HStack(spacing: 4) {
            ShelfActionButton(
                symbol: "eye",
                tint: Color.secondary,
                label: "预览",
                action: onPreview
            )

            if item.isTranslatable {
                ShelfActionButton(
                    symbol: "translate",
                    tint: Color.accentColor,
                    label: "翻译",
                    action: onTranslate
                )
            } else if item.type == .image, imageURL != nil {
                ShelfActionButton(
                    symbol: "text.viewfinder",
                    tint: Color.accentColor,
                    label: "识图并翻译",
                    action: onTranslate
                )
            }

            ShelfActionButton(
                symbol: item.isPinned ? "pin.slash" : "pin",
                tint: item.isPinned ? Color.accentColor : Color.secondary,
                label: item.isPinned ? "取消置顶" : "置顶",
                action: onTogglePin
            )

        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3.5)
        .background {
            Capsule()
                .fill(.regularMaterial)
                .allowsHitTesting(false)
        }
        .overlay {
            Capsule()
                .strokeBorder(Theme.hairlineColor, lineWidth: 0.5)
                .allowsHitTesting(false)
        }
        .shadow(color: Color.black.opacity(0.14), radius: 4, y: 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 7)
    }

    private var bodyContent: some View {
        ZStack {
            bodyShape
                .fill(.regularMaterial)

            bodyShape
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.10),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                )

            content
                .clipShape(bodyShape)

            if isCopied {
                bodyShape
                    .fill(Color.accentColor.opacity(0.09))

                VStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.accentColor)
                    Text("已复制")
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.accentColor)
                }
                .padding(8)
                .background {
                    Capsule()
                        .fill(.regularMaterial)
                }
                .overlay {
                    Capsule()
                        .strokeBorder(
                            Color.accentColor.opacity(0.18),
                            lineWidth: Theme.hairline
                        )
                }
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .overlay {
            bodyShape
                .strokeBorder(
                    isHovering
                        ? Color.accentColor.opacity(0.30)
                        : Theme.hairlineColor,
                    lineWidth: isHovering ? 0.9 : Theme.hairline
                )
        }
        .shadow(
            color: Color.black.opacity(isHovering ? 0.20 : 0.10),
            radius: isHovering ? 14 : 7,
            x: 0,
            y: isHovering ? 7 : 3
        )
        .animation(reduceMotion ? nil : Theme.spring, value: isHovering)
    }

    @ViewBuilder
    private var content: some View {
        switch item.type {
        case .image:
            imageContent
        case .colorHex:
            colorContent
        case .file:
            textContent(isFile: true)
        case .text, .code, .url:
            textContent(isFile: false)
        }
    }

    private var imageContent: some View {
        ZStack(alignment: .bottom) {
            ShelfThumbnailView(
                url: thumbnailURL,
                width: cardWidth,
                height: bodyHeight
            )

            LinearGradient(
                colors: [.clear, Color.black.opacity(0.48)],
                startPoint: .center,
                endPoint: .bottom
            )

            HStack(spacing: 5) {
                Text(item.imageDimensions?.displayText ?? "图片")
                    .lineLimit(1)
                Spacer(minLength: 2)
                Text(RelativeTime.string(from: item.createdAt))
                    .lineLimit(1)
            }
            .font(.system(size: 9, weight: .medium, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.92))
            .padding(.horizontal, 9)
            .padding(.bottom, 8)
        }
    }

    private var colorContent: some View {
        VStack(spacing: 0) {
            if let color = HexColor(hex: item.content) {
                color.color
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay {
                        Text(color.normalizedHex)
                            .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .frame(height: 20)
                            .background {
                                Capsule()
                                    .fill(Color.black.opacity(0.24))
                            }
                    }
            }

            Rectangle()
                .fill(Theme.hairlineColor)
                .frame(height: Theme.hairline)

            HStack(spacing: 5) {
                Image(systemName: item.type.symbolName)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                Text(item.displayTitle)
                    .lineLimit(1)
                Spacer(minLength: 2)
                Text(RelativeTime.string(from: item.createdAt))
                    .lineLimit(1)
            }
            .font(.system(size: 9, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 9)
            .frame(height: 27)
        }
    }

    private func textContent(isFile: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: item.type.symbolName)
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.accentColor)

                Text(item.formatBadge)
                    .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 2)

                Text(RelativeTime.string(from: item.createdAt))
                    .font(.system(size: 8.5, weight: .regular, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Text(item.shelfSnippet)
                .font(
                    .system(
                        size: isFile ? 10.5 : 12,
                        weight: .medium,
                        design: .rounded
                    )
                )
                .foregroundStyle(.primary)
                .lineLimit(
                    ClipboardShelfLayout.textLineLimit(
                        forCardHeight: cardHeight,
                        isFile: isFile
                    )
                )
                .lineSpacing(1.2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)

            Rectangle()
                .fill(Theme.hairlineColor)
                .frame(height: Theme.hairline)

            HStack(spacing: 4) {
                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.accentColor)
                }

                Text(item.sourceApp?.name ?? "剪切板")
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 2)

                Text(detailLabel)
                    .lineLimit(1)
            }
            .font(.system(size: 8.5, weight: .regular, design: .rounded))
            .foregroundStyle(.secondary)
        }
        .padding(11)
    }

    private var detailLabel: String {
        switch item.type {
        case .file:
            return item.fileCount > 0 ? "\(item.fileCount) 个文件" : "文件"
        case .code, .url, .text, .colorHex:
            return "\(item.plainText.count) 字符"
        case .image:
            return item.imageDimensions?.displayText ?? "图片"
        }
    }
}

// MARK: - Actions

private struct ShelfActionButton: View {
    let symbol: String
    let tint: Color
    let label: String
    let action: () -> Void

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
            .foregroundStyle(tint)
            .frame(width: 19, height: 19)
            .background {
                Circle()
                    .fill(.regularMaterial)
                    .allowsHitTesting(false)
            }
            .overlay {
                Circle()
                    .strokeBorder(Theme.hairlineColor, lineWidth: 0.5)
                    .allowsHitTesting(false)
            }
            .contentShape(Circle())
            .onTapGesture(perform: action)
            .shadow(color: Color.black.opacity(0.12), radius: 2, y: 1)
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                action()
            }
    }
}

// MARK: - Clip

private struct ShelfClipView: View {
    let isPinned: Bool
    let isHovering: Bool
    let onDelete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isOpen = false

    private var wood: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.84, green: 0.69, blue: 0.49),
                Color(red: 0.60, green: 0.44, blue: 0.27)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var spring: Color {
        Color(red: 0.36, green: 0.31, blue: 0.25)
    }

    var body: some View {
        ZStack {
            Capsule()
                .fill(wood)
                .frame(width: 3.6, height: 12)
                .rotationEffect(
                    .degrees(isOpen ? 22 : -6),
                    anchor: .top
                )
                .offset(x: 2.2, y: 4)

            Capsule()
                .fill(wood)
                .frame(width: 3.6, height: 12)
                .rotationEffect(
                    .degrees(isOpen ? -22 : 6),
                    anchor: .top
                )
                .offset(x: -2.2, y: 4)

            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(wood)
                .frame(width: 11, height: 8)
                .offset(y: -4)

            Circle()
                .fill(Color.black.opacity(0.22))
                .frame(width: 2.2, height: 2.2)
                .offset(y: -4)

            Capsule()
                .fill(spring)
                .frame(width: 10.5, height: 2)
                .offset(y: 0.5)

            Circle()
                .stroke(spring, lineWidth: 1.2)
                .frame(width: 4, height: 4)
                .offset(x: 5.2, y: 0.5)

            Capsule()
                .fill(Color.white.opacity(0.34))
                .frame(width: 1.2, height: 5)
                .offset(x: -2.6, y: -4)

            if isPinned {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 2.2, height: 2.2)
                    .offset(y: -4)
            }
        }
        .frame(width: 14, height: ClipboardShelfLayout.clipHeight)
        .scaleEffect(isHovering ? 1.06 : 1)
        .shadow(color: Color.black.opacity(0.18), radius: 1.5, y: 1)
        .contentShape(Rectangle())
        .onTapGesture(perform: unclip)
        .help("点击松开夹子并删除")
        .accessibilityElement()
        .accessibilityLabel("松开夹子并删除")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            unclip()
        }
    }

    private func unclip() {
        guard !isOpen else { return }
        withAnimation(
            reduceMotion
                ? nil
                : .spring(response: 0.18, dampingFraction: 0.62)
        ) {
            isOpen = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            onDelete()
        }
    }
}

private struct ShelfThumbnailView: View {
    let url: URL?
    let width: CGFloat
    let height: CGFloat

    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            } else {
                ZStack {
                    Color.primary.opacity(0.05)
                    Image(systemName: "photo")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: width, height: height)
        .clipped()
        .task(id: url) {
            image = url.flatMap(NSImage.init(contentsOf:))
        }
    }
}
