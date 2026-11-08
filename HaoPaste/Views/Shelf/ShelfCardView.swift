//
//  ShelfCardView.swift
//  HaoPaste
//
//  One clipboard card hanging from the shelf line.
//

import AppKit
import SwiftUI

struct ShelfCardView: View {
    let item: ClipboardItem
    let cardWidth: CGFloat
    let thumbnailURL: URL?
    let isCopied: Bool
    let baseAngle: Double
    let onCopy: () -> Void

    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let bodyHeight = ClipboardShelfLayout.cardBodyHeight

    var body: some View {
        VStack(spacing: 0) {
            clip
            bodyContent
        }
        .rotationEffect(
            .degrees(isHovering || reduceMotion ? 0 : baseAngle),
            anchor: .top
        )
        .offset(y: isHovering && !reduceMotion ? -4 : 0)
        .scaleEffect(
            isHovering && !reduceMotion ? 1.025 : 1,
            anchor: .top
        )
        .animation(reduceMotion ? nil : Theme.spring, value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture(perform: onCopy)
        .help("点击复制")
        .accessibilityLabel("\(item.formatBadge)，\(item.displayTitle)")
        .accessibilityHint("复制到剪贴板")
    }

    private var clip: some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(
                    item.isPinned
                        ? Color.secondary.opacity(0.72)
                        : Color.accentColor
                )
                .frame(width: 11, height: 14)

            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.30))
                .frame(width: 2, height: 7)
        }
        .frame(height: ClipboardShelfLayout.clipHeight)
        .shadow(color: Color.black.opacity(0.16), radius: 1.5, y: 1)
    }

    private var bodyContent: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.regularMaterial)

            content
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            if isCopied {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.accentColor.opacity(0.08))

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
                        .strokeBorder(Color.accentColor.opacity(0.18), lineWidth: Theme.hairline)
                }
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .frame(width: cardWidth, height: bodyHeight)
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    isHovering
                        ? Color.accentColor.opacity(0.28)
                        : Theme.hairlineColor,
                    lineWidth: isHovering ? 0.8 : Theme.hairline
                )
        }
        .shadow(
            color: Color.black.opacity(isHovering ? 0.18 : 0.08),
            radius: isHovering ? 12 : 6,
            x: 0,
            y: isHovering ? 6 : 3
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
                colors: [.clear, Color.black.opacity(0.46)],
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
            .foregroundStyle(Color.white.opacity(0.90))
            .padding(.horizontal, 8)
            .padding(.bottom, 7)
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
                                    .fill(Color.black.opacity(0.22))
                            }
                    }
            }

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
            .padding(.horizontal, 8)
            .frame(height: 26)
        }
    }

    private func textContent(isFile: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
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
                        size: isFile ? 10.5 : 11.5,
                        weight: .medium,
                        design: .rounded
                    )
                )
                .foregroundStyle(.primary)
                .lineLimit(isFile ? 3 : 4)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)

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
        .padding(10)
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
