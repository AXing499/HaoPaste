//
//  ShelfPreviewPanelController.swift
//  HaoPaste
//
//  Preview card presented next to the shelf, without leaving the shelf.
//

import AppKit
import SwiftUI

@MainActor
final class ShelfPreviewPanelController: NSObject, NSWindowDelegate {
    private let manager: ClipboardManager
    private let panel = ShelfDetailPanel()
    private let panelSize = NSSize(width: 620, height: 452)

    private var anchor: NSRect?
    private var edge: ClipboardShelfEdge = .top

    var onTranslateText: ((
        String,
        String,
        NSRect,
        ClipboardShelfEdge
    ) -> Void)?
    var onExtractText: ((
        ClipboardItem,
        URL,
        NSRect,
        ClipboardShelfEdge
    ) -> Void)?

    var isVisible: Bool {
        panel.isVisible
    }

    init(manager: ClipboardManager) {
        self.manager = manager
        super.init()
        panel.delegate = self
    }

    func present(
        item: ClipboardItem,
        anchor: NSRect,
        edge: ClipboardShelfEdge
    ) {
        self.anchor = anchor
        self.edge = edge

        let imageURL = manager.imageURL(for: item)
        let richText = manager.richText(for: item)

        let view = PreviewOverlayView(
            item: item,
            imageURL: imageURL,
            richText: richText,
            onClose: { [weak self] in
                self?.hide()
            },
            onCopy: { [weak self] in
                guard let self else { return }
                _ = self.manager.copyToPasteboard(item)
                self.hide()
            },
            onCopyText: { [weak self] text in
                guard let self else { return }
                _ = self.manager.copyTextToPasteboard(text)
                self.hide()
            },
            onOpenURL: { url in
                NSWorkspace.shared.open(url)
            },
            onOpenFiles: {
                for url in item.availableFileURLs {
                    NSWorkspace.shared.open(url)
                }
            },
            onRevealFiles: {
                NSWorkspace.shared.activateFileViewerSelecting(
                    item.availableFileURLs
                )
            },
            onSaveImage: {
                if let imageURL {
                    ImageSavePanel.present(imageURL: imageURL)
                }
            },
            onTranslate: { [weak self] in
                guard let self, let anchor = self.anchor else { return }
                self.hide()
                self.onTranslateText?(
                    item.content,
                    item.displayTitle,
                    anchor,
                    self.edge
                )
            },
            onExtractText: { [weak self] in
                guard let self, let imageURL, let anchor = self.anchor else {
                    return
                }
                self.hide()
                self.onExtractText?(
                    item,
                    imageURL,
                    anchor,
                    self.edge
                )
            },
            showsScrim: false
        )
        .frame(width: panelSize.width, height: panelSize.height)

        let hostingView = NSHostingView(rootView: view)
        hostingView.sizingOptions = []
        hostingView.frame = NSRect(origin: .zero, size: panelSize)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = hostingView

        let target = ClipboardShelfLayout.centeredDetailFrame(
            size: panelSize,
            anchor: anchor
        )
        panel.setFrame(target, display: false)
        panel.alphaValue = 0
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(
                controlPoints: 0.16, 1, 0.3, 1
            )
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        panel.alphaValue = 1
        panel.contentView = nil
    }

    func close() {
        hide()
    }

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }
}
