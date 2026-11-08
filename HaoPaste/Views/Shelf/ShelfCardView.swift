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
    let isHovering: Bool
    let isCopied: Bool
    let baseAngle: Double
    let canDragOut: Bool
    let dragProvider: () -> NSItemProvider
    let onCopy: () -> Void
    let onCopyPlainText: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let bodyHeight = ClipboardShelfLayout.cardBodyHeight
    private static let bodyOffset = ClipboardShelfLayout.bodyOffset

    private var bodyShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 11, style: .continuous)
    }

    var body: some View {
        ZStack(alignment: .top) {
            copySurface
                .contentShape(Rectangle())
                .onTapGesture(perform: onCopy)

            if isHovering {
                actionCluster
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .frame(
            width: cardWidth,
            height: ClipboardShelfLayout.cardHeight,
            alignment: .top
        )
        .rotationEffect(
            .degrees(isHovering || reduceMotion ? 0 : baseAngle),
            anchor: .top
        )
        .offset(y: isHovering && !reduceMotion ? -5 : 0)
        .scaleEffect(
            isHovering && !reduceMotion ? 1.035 : 1,
            anchor: .top
        )
        .animation(reduceMotion ? nil : Theme.spring, value: isHovering)
        .help("点击复制")
        .accessibilityLabel("\(item.formatBadge)，\(item.displayTitle)")
        .accessibilityHint("复制到剪贴板")
        .contextMenu {
            Button {
                onCopy()
            } label: {
                Label("复制", systemImage: "doc.on.doc")
            }

            Button {
                onTogglePin()
            } label: {
                Label(
                    item.isPinned ? "取消置顶" : "置顶",
                    systemImage: item.isPinned ? "pin.slash" : "pin"
                )
            }

            if item.isTextLike {
                Button {
                    onCopyPlainText()
                } label: {
                    Label("复制纯文本", systemImage: "textformat")
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
    private var copySurface: some View {
        let surface = ZStack(alignment: .top) {
            bodyContent
                .frame(width: cardWidth, height: Self.bodyHeight)
                .offset(y: Self.bodyOffset)

            ShelfClipView(
                isPinned: item.isPinned,
                isHovering: isHovering
            )
        }

        if canDragOut {
            surface.onDrag(dragProvider)
        } else {
            surface
        }
    }

    private var actionCluster: some View {
        HStack(spacing: 4) {
            ShelfActionButton(
                symbol: item.isPinned ? "pin.slash" : "pin",
                tint: item.isPinned ? Color.accentColor : Color.secondary,
                label: item.isPinned ? "取消置顶" : "置顶",
                action: onTogglePin
            )

            ShelfActionButton(
                symbol: "trash",
                tint: Color.red.opacity(0.9),
                label: "删除",
                action: onDelete
            )
        }
        .padding(.top, Self.bodyOffset + 6)
        .padding(.trailing, 7)
        .frame(maxWidth: .infinity, alignment: .trailing)
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
                height: Self.bodyHeight
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

            Text(item.displayTitle)
                .font(
                    .system(
                        size: isFile ? 10.5 : 12,
                        weight: .medium,
                        design: .rounded
                    )
                )
                .foregroundStyle(.primary)
                .lineLimit(isFile ? 3 : 4)
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

    private var metal: LinearGradient {
        LinearGradient(
            colors: [
                Color.primary.opacity(0.34),
                Color.primary.opacity(0.14)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        ZStack {
            Capsule()
                .fill(metal)
                .frame(width: 3.2, height: 10)
                .rotationEffect(.degrees(8))
                .offset(x: 2.1, y: 3)

            Capsule()
                .fill(metal)
                .frame(width: 3.2, height: 10)
                .rotationEffect(.degrees(-8))
                .offset(x: -2.1, y: 3)

            RoundedRectangle(cornerRadius: 2.2, style: .continuous)
                .fill(metal)
                .frame(width: 9.5, height: 7.5)
                .offset(y: -2.9)

            Capsule()
                .fill(
                    isPinned
                        ? Color.secondary.opacity(0.82)
                        : Color.accentColor.opacity(isHovering ? 1 : 0.86)
                )
                .frame(width: 10, height: 2)
                .offset(y: 0.5)

            Capsule()
                .fill(Color.white.opacity(0.45))
                .frame(width: 1.2, height: 5)
                .offset(x: -2.2, y: -2.9)

            if isPinned {
                Circle()
                    .fill(Color.white.opacity(0.86))
                    .frame(width: 1.6, height: 1.6)
                    .offset(y: -2.9)
            }
        }
        .frame(
            width: 13,
            height: ClipboardShelfLayout.clipHeight
        )
        .shadow(color: Color.black.opacity(0.18), radius: 1.5, y: 1)
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
