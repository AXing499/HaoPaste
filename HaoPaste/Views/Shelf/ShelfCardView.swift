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
    let edge: ClipboardShelfEdge
    let fallDirection: CGFloat
    let fallDuration: TimeInterval
    let canDragOut: Bool
    let dragProvider: () -> NSItemProvider
    let onCopy: () -> Void
    let onCopyText: (String) -> Void
    let onCopyPlainText: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void
    let onPreview: () -> Void
    let onTranslate: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isFalling = false

    private var animates: Bool {
        !reduceMotion && !DebugMotion.disablesAnimations
    }
    @State private var isClipDropping = false
    @State private var copyPulse = false

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
            ZStack(alignment: .top) {
                bodySurface
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onCopy)

                if isHovering {
                    actionBar
                        .transition(
                            .opacity.combined(with: .scale(scale: 0.94))
                        )
                }
            }
            .scaleEffect(
                isHovering && animates ? 1.03 : 1,
                anchor: rotationAnchor
            )
            .animation(
                animates ? Theme.spring : nil,
                value: isHovering
            )
            .offset(
                x: isFalling ? 16 * fallDirection : 0,
                y: isFalling ? 150 : 0
            )
            .rotationEffect(
                .degrees(isFalling ? 9 * Double(fallDirection) : 0),
                anchor: .top
            )
            .opacity(isFalling ? 0 : 1)
            .animation(
                animates ? .easeIn(duration: fallDuration) : nil,
                value: isFalling
            )

            ShelfClipView(
                itemID: item.id,
                isPinned: item.isPinned,
                isHovering: isHovering,
                isDropping: isClipDropping,
                dropDuration: clipDropDuration,
                onRelease: release
            )
            .frame(maxWidth: .infinity, alignment: clipAlignment)
        }
        .frame(
            width: cardWidth,
            height: cardHeight,
            alignment: .top
        )
        .scaleEffect(isCopied && animates ? 1.015 : 1)
        .animation(animates ? Theme.spring : nil, value: isCopied)
        .onChange(of: isCopied) { _, copied in
            if copied { copyPulse.toggle() }
        }
        .allowsHitTesting(!isFalling && !isClipDropping)
        .help(L("点击复制"))
        .accessibilityLabel("\(item.formatBadge)，\(item.displayTitle)")
        .accessibilityHint(L("复制到剪贴板"))
        .contextMenu {
            Button {
                onPreview()
            } label: {
                Label(L("预览"), systemImage: "eye")
            }

            Button {
                onCopy()
            } label: {
                Label(L("复制"), systemImage: "doc.on.doc")
            }

            if item.isTranslatable {
                Button {
                    onTranslate()
                } label: {
                    Label(L("翻译…"), systemImage: "translate")
                }
            } else if item.type == .image, imageURL != nil {
                Button {
                    onTranslate()
                } label: {
                    Label(L("提取文字…"), systemImage: "text.viewfinder")
                }
            }

            Button {
                onTogglePin()
            } label: {
                Label(
                    item.isPinned ? L("取消置顶") : L("置顶"),
                    systemImage: item.isPinned ? "pin.slash" : "pin"
                )
            }

            if item.type == .text
                || item.type == .code
                || item.type == .url
                || item.type == .colorHex {
                Button {
                    onCopyPlainText()
                } label: {
                    Label(L("复制为纯文本"), systemImage: "textformat")
                }
            }

            if item.type == .url, let url = URL(string: item.content) {
                Divider()

                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Label(L("打开链接"), systemImage: "safari")
                }

                Button {
                    let title = url.host ?? item.displayTitle
                    onCopyText("[\(title)](\(item.content))")
                } label: {
                    Label(L("复制为 Markdown 链接"), systemImage: "doc.on.doc")
                }
            }

            if item.type == .file {
                Divider()

                Button {
                    for url in item.availableFileURLs {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label(L("打开文件"), systemImage: "arrow.up.forward.app")
                }
                .disabled(item.availableFileURLs.isEmpty)

                Button {
                    NSWorkspace.shared.activateFileViewerSelecting(
                        item.availableFileURLs
                    )
                } label: {
                    Label(L("在 Finder 中显示"), systemImage: "folder")
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
                    Label(L("保存图片…"), systemImage: "square.and.arrow.down")
                }
            }

            if item.type == .colorHex, let color = HexColor(hex: item.content) {
                Divider()

                Button {
                    onCopyText(color.normalizedHex)
                } label: {
                    Label(
                        L("复制 HEX（%@）", color.normalizedHex),
                        systemImage: "paintpalette"
                    )
                }

                Button {
                    onCopyText(color.rgbString)
                } label: {
                    Label(
                        L("复制 RGB（%@）", color.rgbString),
                        systemImage: "paintpalette"
                    )
                }

                Button {
                    onCopyText(color.hslString)
                } label: {
                    Label(
                        L("复制 HSL（%@）", color.hslString),
                        systemImage: "paintpalette"
                    )
                }
            }

            Divider()

            Button(role: .destructive) {
                release()
            } label: {
                Label(L("删除"), systemImage: "trash")
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
                label: L("预览"),
                action: onPreview
            )

            if item.isTranslatable {
                ShelfActionButton(
                    symbol: "translate",
                    tint: Color.accentColor,
                    label: L("翻译"),
                    action: onTranslate
                )
            } else if item.type == .image, imageURL != nil {
                ShelfActionButton(
                    symbol: "text.viewfinder",
                    tint: Color.accentColor,
                    label: L("提取文字"),
                    action: onTranslate
                )
            }

            ShelfActionButton(
                symbol: item.isPinned ? "pin.slash" : "pin",
                tint: item.isPinned ? Color.accentColor : Color.secondary,
                label: item.isPinned ? L("取消置顶") : L("置顶"),
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
        .shelfHitArea(.cardActions(item.id))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 7)
    }

    private var bodyContent: some View {
        ZStack {
            GlassSurfaceBackground(
                shape: bodyShape,
                fallback: .material
            )
            .allowsHitTesting(false)

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
                        .symbolEffect(
                            .bounce,
                            options: .nonRepeating,
                            value: copyPulse
                        )
                    Text(L("已复制"))
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
        .animation(animates ? Theme.spring : nil, value: isHovering)
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
                Text(item.imageDimensions?.displayText ?? L("图片"))
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

                Text(item.sourceApp?.name ?? L("剪切板"))
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
            return item.fileCount > 0
                ? L("%d 个文件", item.fileCount)
                : L("文件")
        case .code, .url, .text, .colorHex:
            return L("%d 字符", item.plainText.count)
        case .image:
            return item.imageDimensions?.displayText ?? L("图片")
        }
    }

    private var clipDropDuration: TimeInterval {
        min(0.4, max(0.2, fallDuration * 0.6))
    }

    private func release() {
        guard !isFalling else { return }

        let bodyDuration = max(0.1, fallDuration)
        let dropDuration = clipDropDuration
        let dropDelay = bodyDuration * 0.5

        withAnimation(
            animates ? .easeIn(duration: bodyDuration) : nil
        ) {
            isFalling = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + dropDelay) {
            withAnimation(
                animates ? .easeIn(duration: dropDuration) : nil
            ) {
                isClipDropping = true
            }
        }

        let total = animates
            ? max(bodyDuration, dropDelay + dropDuration) + 0.05
            : 0.1
        DispatchQueue.main.asyncAfter(deadline: .now() + total) {
            onDelete()
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
        Button(action: action) {
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
                .shadow(color: Color.black.opacity(0.12), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(label)
        .accessibilityLabel(label)
    }
}

// MARK: - Clip

private struct ShelfClipView: View {
    let itemID: UUID
    let isPinned: Bool
    let isHovering: Bool
    let isDropping: Bool
    let dropDuration: TimeInterval
    let onRelease: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isOpen = false

    private var gold: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.97, green: 0.75, blue: 0.30),
                Color(red: 0.86, green: 0.56, blue: 0.10)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var wire: Color {
        Color(red: 0.18, green: 0.16, blue: 0.19)
    }

    private var feet: Color {
        Color(red: 0.55, green: 0.54, blue: 0.92)
    }

    var body: some View {
        ZStack {
            BinderClipBody()
                .fill(gold)

            BinderClipWire()
                .stroke(
                    wire,
                    style: StrokeStyle(
                        lineWidth: 1.4,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )

            HStack(spacing: 1.2) {
                Capsule().fill(feet).frame(width: 3, height: 2.5)
                Capsule().fill(feet).frame(width: 4, height: 2.5)
                Capsule().fill(feet).frame(width: 3, height: 2.5)
            }
            .offset(y: 6.2)

            Capsule()
                .fill(Color.white.opacity(0.38))
                .frame(width: 1.4, height: 4.2)
                .offset(x: -3.6, y: -0.8)

            if isPinned {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 2.2, height: 2.2)
                    .offset(x: -3.4, y: 4.6)
            }
        }
        .frame(width: 14, height: ClipboardShelfLayout.clipHeight)
        .rotationEffect(
            .degrees(isOpen ? -14 : 0),
            anchor: .top
        )
        .offset(y: isOpen ? -3 : 0)
        .rotationEffect(
            .degrees(isDropping ? 24 : 0),
            anchor: .top
        )
        .offset(y: isDropping ? 42 : 0)
        .opacity(isDropping ? 0 : 1)
        .scaleEffect(isHovering ? 1.06 : 1)
        .shadow(color: Color.black.opacity(0.18), radius: 1.5, y: 1)
        .contentShape(Rectangle())
        .allowsHitTesting(!isDropping)
        .shelfHitArea(.cardClip(itemID))
        .onTapGesture(perform: unclip)
        .help(L("点击松开夹子并删除"))
        .accessibilityElement()
        .accessibilityLabel(L("松开夹子并删除"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            unclip()
        }
        .animation(
            reduceMotion
                ? nil
                : .spring(response: 0.18, dampingFraction: 0.62),
            value: isOpen
        )
        .animation(
            reduceMotion
                ? nil
                : .easeIn(duration: dropDuration),
            value: isDropping
        )
        .onChange(of: itemID) { _, _ in
            isOpen = false
        }
    }

    private func unclip() {
        guard !isOpen, !isDropping else { return }
        withAnimation(
            reduceMotion
                ? nil
                : .spring(response: 0.18, dampingFraction: 0.62)
        ) {
            isOpen = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onRelease()
        }
    }
}

private struct BinderClipBody: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let top: CGFloat = 5.6
        path.move(to: CGPoint(x: 2.4, y: top))
        path.addQuadCurve(
            to: CGPoint(x: 3.4, y: 4.9),
            control: CGPoint(x: 2.6, y: 4.9)
        )
        path.addLine(to: CGPoint(x: 10.6, y: 4.9))
        path.addQuadCurve(
            to: CGPoint(x: 11.6, y: top),
            control: CGPoint(x: 11.4, y: 4.9)
        )
        path.addLine(to: CGPoint(x: 11.0, y: 13.7))
        path.addQuadCurve(
            to: CGPoint(x: 10.1, y: 14.4),
            control: CGPoint(x: 10.9, y: 14.4)
        )
        path.addLine(to: CGPoint(x: 3.9, y: 14.4))
        path.addQuadCurve(
            to: CGPoint(x: 3.0, y: 13.7),
            control: CGPoint(x: 3.1, y: 14.4)
        )
        path.closeSubpath()
        return path
    }
}

private struct BinderClipWire: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // The wire fans outward at the top, then converges into the clip feet.
        path.move(to: CGPoint(x: 4.6, y: 15.0))
        path.addLine(to: CGPoint(x: 3.8, y: 7.6))
        path.addCurve(
            to: CGPoint(x: 7.0, y: 1.0),
            control1: CGPoint(x: 3.3, y: 3.2),
            control2: CGPoint(x: 4.7, y: 1.0)
        )
        path.addCurve(
            to: CGPoint(x: 10.2, y: 7.6),
            control1: CGPoint(x: 9.3, y: 1.0),
            control2: CGPoint(x: 10.7, y: 3.2)
        )
        path.addLine(to: CGPoint(x: 9.4, y: 15.0))
        return path
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
