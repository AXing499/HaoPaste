//
//  MultiFileDragHandle.swift
//  HaoPaste
//
//  A small AppKit drag source used for multi-file clipboard items. SwiftUI's
//  onDrag can only expose one NSItemProvider, while Finder needs one dragging
//  item per file URL.
//

import AppKit
import SwiftUI

struct MultiFileDragHandle: NSViewRepresentable {
    let fileURLs: [URL]
    let onClick: () -> Void

    func makeNSView(context: Context) -> MultiFileDragSourceView {
        let view = MultiFileDragSourceView()
        view.fileURLs = fileURLs
        view.onClick = onClick
        return view
    }

    func updateNSView(_ view: MultiFileDragSourceView, context: Context) {
        view.fileURLs = fileURLs
        view.onClick = onClick
    }
}

final class MultiFileDragSourceView: NSView, NSDraggingSource {
    var fileURLs: [URL] = []
    var onClick: (() -> Void)?

    private var mouseDownEvent: NSEvent?
    private var hasStartedDrag = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        toolTip = L("拖动以复制全部文件")
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(L("拖动以复制全部文件"))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
        hasStartedDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !hasStartedDrag, let mouseDownEvent, !fileURLs.isEmpty else {
            return
        }

        hasStartedDrag = true
        let items = Self.draggingItems(
            for: fileURLs,
            centeredAt: NSPoint(x: bounds.midX, y: bounds.midY)
        )
        beginDraggingSession(
            with: items,
            event: mouseDownEvent,
            source: self
        )
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            mouseDownEvent = nil
            hasStartedDrag = false
        }
        guard !hasStartedDrag else { return }
        onClick?()
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        .copy
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        mouseDownEvent = nil
        hasStartedDrag = false
    }

    static func draggingItems(
        for urls: [URL],
        centeredAt point: NSPoint
    ) -> [NSDraggingItem] {
        urls.enumerated().map { index, url in
            let pasteboardItem = NSPasteboardItem()
            pasteboardItem.setString(
                url.absoluteString,
                forType: .fileURL
            )
            let item = NSDraggingItem(pasteboardWriter: pasteboardItem)

            let icon = NSWorkspace.shared.icon(forFile: url.path)
            icon.size = NSSize(width: 32, height: 32)
            let offset = CGFloat(index) * 5
            item.setDraggingFrame(
                NSRect(
                    x: point.x - 16 + offset,
                    y: point.y - 16 + offset,
                    width: 32,
                    height: 32
                ),
                contents: icon
            )
            return item
        }
    }
}
