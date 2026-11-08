//
//  DemoContent.swift
//  HaoPaste
//
//  DEBUG-only sample history for visual QA and screenshots.
//

#if DEBUG
import AppKit

@MainActor
enum DemoContent {
    static func makeItems(store: ClipboardStore) -> [ClipboardItem] {
        let now = Date()
        var items: [ClipboardItem] = []

        func textItem(
            _ text: String,
            type: ClipboardItemType,
            source: String,
            ago: TimeInterval,
            pinned: Bool = false
        ) -> ClipboardItem {
            ClipboardItem(
                type: type,
                content: text,
                plainText: text,
                isPinned: pinned,
                createdAt: now.addingTimeInterval(-ago),
                sourceApp: SourceApplication(bundleIdentifier: nil, name: source),
                contentHash: ContentHasher.text(text, type: type)
            )
        }

        items.append(
            textItem(
                "把复杂留给系统，把简单留给用户。",
                type: .text,
                source: "备忘录",
                ago: 120,
                pinned: true
            )
        )

        let swiftSnippet = """
        struct ClipboardPanel: View {
            var body: some View {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.primary.opacity(0.08), lineWidth: 0.5)
                    }
            }
        }
        """

        items.append(
            textItem(
                swiftSnippet,
                type: .code,
                source: "Xcode",
                ago: 60
            )
        )

        let url = "https://developer.apple.com/design/human-interface-guidelines"
        items.append(
            textItem(url, type: .url, source: "Safari", ago: 240)
        )

        let json = """
        {
          "name": "HaoPaste",
          "features": ["search", "pin", "quick-copy", "app-exclusions"]
        }
        """
        items.append(
            textItem(json, type: .code, source: "VS Code", ago: 480)
        )

        items.append(
            textItem(
                "#FF8A5B",
                type: .colorHex,
                source: "Figma",
                ago: 300
            )
        )

        items.append(
            textItem(
                "明天的评审改到下午三点，记得带上最新的设计稿。",
                type: .text,
                source: "飞书",
                ago: 1_800
            )
        )

        let github = "https://github.com/haopaste/HaoPaste"
        items.append(
            textItem(github, type: .url, source: "Safari", ago: 3_600)
        )

        let demoFilePaths = [
            "/System/Applications/Calculator.app",
            "/System/Applications/Notes.app"
        ].filter { FileManager.default.fileExists(atPath: $0) }

        if !demoFilePaths.isEmpty {
            let names = demoFilePaths.map { URL(fileURLWithPath: $0).lastPathComponent }
            items.append(
                ClipboardItem(
                    type: .file,
                    content: demoFilePaths.joined(separator: "\n"),
                    plainText: (names + demoFilePaths).joined(separator: "\n"),
                    isPinned: false,
                    createdAt: now.addingTimeInterval(-360),
                    sourceApp: SourceApplication(
                        bundleIdentifier: "com.apple.finder",
                        name: "访达"
                    ),
                    contentHash: ContentHasher.files(demoFilePaths),
                    filePaths: demoFilePaths
                )
            )
        }

        items.append(
            textItem(
                "npm run build && open .build/Build/Products/Debug/HaoPaste.app",
                type: .text,
                source: "终端",
                ago: 5_400
            )
        )

        if let imageData = makeDemoImageData() {
            let id = UUID()
            if let stored = try? store.saveImage(data: imageData, id: id) {
                items.append(
                    ClipboardItem(
                        id: id,
                        type: .image,
                        content: stored.fileName,
                        plainText: "图片 \(stored.dimensions.displayText)",
                        isPinned: false,
                        createdAt: now.addingTimeInterval(-320),
                        sourceApp: SourceApplication(
                            bundleIdentifier: nil,
                            name: "截图"
                        ),
                        contentHash: ContentHasher.imageData(imageData),
                        imageFileName: stored.fileName,
                        thumbnailFileName: stored.thumbnailFileName,
                        imageDimensions: stored.dimensions
                    )
                )
            }
        }

        return items
    }

    private static func makeDemoImageData() -> Data? {
        let width = 1_440
        let height = 900

        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }

        bitmap.size = NSSize(width: width, height: height)

        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high

        let bounds = NSRect(x: 0, y: 0, width: width, height: height)

        let gradient = NSGradient(colors: [
            NSColor.systemBlue,
            NSColor.systemIndigo,
            NSColor.systemTeal
        ])
        gradient?.draw(in: bounds, angle: -35)

        NSColor.white.withAlphaComponent(0.10).setFill()
        NSBezierPath(
            ovalIn: NSRect(x: 810, y: 170, width: 700, height: 700)
        ).fill()

        NSColor.white.withAlphaComponent(0.08).setFill()
        NSBezierPath(
            roundedRect: NSRect(x: 110, y: 120, width: 560, height: 370),
            xRadius: 54,
            yRadius: 54
        ).fill()

        let title = "HaoPaste" as NSString
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 126, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        title.draw(
            at: NSPoint(x: 126, y: 300),
            withAttributes: titleAttributes
        )

        let subtitle = "Clipboard, reimagined." as NSString
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 42, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.78)
        ]
        subtitle.draw(
            at: NSPoint(x: 132, y: 238),
            withAttributes: subtitleAttributes
        )

        NSGraphicsContext.restoreGraphicsState()

        return bitmap.representation(using: .png, properties: [:])
    }
}
#endif

#if DEBUG
@MainActor
extension SnippetManager {
    func seedDemoSnippetsIfNeeded() {
        guard snippets.isEmpty else { return }

        _ = create(
            title: "工作邮箱",
            content: "hello@haopaste.app"
        )
        _ = create(
            title: "HaoPaste 签名",
            content: "—— 来自 HaoPaste\nClipboard, reimagined."
        )
        _ = create(
            title: "构建命令",
            content: "swift build && swift test"
        )
        _ = create(
            title: "会议纪要模板",
            content: """
            议题：
            结论：
            下一步：
            """
        )
    }
}
#endif
