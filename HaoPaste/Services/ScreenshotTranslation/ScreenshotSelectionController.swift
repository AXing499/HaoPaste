//
//  ScreenshotSelectionController.swift
//  HaoPaste
//
//  Full-screen region picker used by screenshot OCR and translation.
//

import AppKit

@MainActor
final class ScreenshotSelectionController {
    private var window: ScreenshotSelectionWindow?
    private var completion: ((NSRect, NSScreen) -> Void)?
    private var cancellation: (() -> Void)?
    private var isCursorPushed = false

    var isSelecting: Bool {
        window != nil
    }

    func begin(
        on screen: NSScreen,
        completion: @escaping (NSRect, NSScreen) -> Void,
        onCancel: @escaping () -> Void
    ) {
        cancel()

        self.completion = completion
        self.cancellation = onCancel

        let window = ScreenshotSelectionWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .screenSaver
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .transient,
            .ignoresCycle
        ]

        let view = ScreenshotSelectionView(
            frame: NSRect(origin: .zero, size: screen.frame.size),
            onComplete: { [weak self, weak window] rect in
                guard let self, let window else { return }
                let screenRect = window.convertToScreen(rect)
                let targetScreen = screen
                let completion = self.completion
                self.finish()
                completion?(screenRect, targetScreen)
            },
            onCancel: { [weak self] in
                self?.cancel()
            }
        )
        window.contentView = view
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(view)

        NSCursor.crosshair.push()
        isCursorPushed = true
    }

    func cancel() {
        let cancellation = self.cancellation
        finish()
        cancellation?()
    }

    private func finish() {
        if isCursorPushed {
            NSCursor.pop()
            isCursorPushed = false
        }
        window?.orderOut(nil)
        window?.contentView = nil
        window = nil
        completion = nil
        cancellation = nil
    }
}

private final class ScreenshotSelectionWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class ScreenshotSelectionView: NSView {
    private var startPoint: NSPoint?
    private var selectionRect = NSRect.zero
    private var trackingArea: NSTrackingArea?
    private let onComplete: (NSRect) -> Void
    private let onCancel: () -> Void

    init(
        frame: NSRect,
        onComplete: @escaping (NSRect) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onComplete = onComplete
        self.onCancel = onCancel
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.cursorUpdate, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        selectionRect = .zero
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let startPoint else { return }
        let current = convert(event.locationInWindow, from: nil)
        selectionRect = NSRect(
            x: min(startPoint.x, current.x),
            y: min(startPoint.y, current.y),
            width: abs(current.x - startPoint.x),
            height: abs(current.y - startPoint.y)
        )
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        startPoint = nil
        guard selectionRect.width >= 8, selectionRect.height >= 8 else {
            selectionRect = .zero
            needsDisplay = true
            return
        }
        onComplete(selectionRect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel()
            return
        }
        super.keyDown(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let mask = NSBezierPath(rect: bounds)
        if !selectionRect.isEmpty {
            mask.append(NSBezierPath(rect: selectionRect))
        }
        mask.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.36).setFill()
        mask.fill()

        drawInstruction()
        guard !selectionRect.isEmpty else { return }

        let border = NSBezierPath(
            rect: selectionRect.insetBy(dx: 0.5, dy: 0.5)
        )
        border.lineWidth = 1
        NSColor.white.withAlphaComponent(0.92).setStroke()
        border.stroke()

        drawSizeBadge()
    }

    private func drawInstruction() {
        let text = L("拖拽选择截图区域 · esc 取消") as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let size = text.size(withAttributes: attributes)
        let rect = NSRect(
            x: bounds.midX - size.width / 2 - 14,
            y: bounds.maxY - size.height - 36,
            width: size.width + 28,
            height: size.height + 14
        )
        NSColor.black.withAlphaComponent(0.60).setFill()
        NSBezierPath(
            roundedRect: rect,
            xRadius: rect.height / 2,
            yRadius: rect.height / 2
        ).fill()
        text.draw(
            at: NSPoint(
                x: rect.midX - size.width / 2,
                y: rect.midY - size.height / 2
            ),
            withAttributes: attributes
        )
    }

    private func drawSizeBadge() {
        let text = "\(Int(selectionRect.width)) × \(Int(selectionRect.height))" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        let size = text.size(withAttributes: attributes)
        let badge = NSRect(
            x: selectionRect.minX + 8,
            y: selectionRect.maxY - size.height - 18,
            width: size.width + 14,
            height: size.height + 8
        )
        NSColor.black.withAlphaComponent(0.64).setFill()
        NSBezierPath(
            roundedRect: badge,
            xRadius: 5,
            yRadius: 5
        ).fill()
        text.draw(
            at: NSPoint(
                x: badge.midX - size.width / 2,
                y: badge.midY - size.height / 2
            ),
            withAttributes: attributes
        )
    }
}
