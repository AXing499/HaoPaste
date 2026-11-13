//
//  ShelfOCRPanelController.swift
//  HaoPaste
//
//  OCR card presented next to the shelf, without leaving the shelf.
//

import AppKit
import SwiftUI

@MainActor
final class ShelfOCRPanelController: NSObject, NSWindowDelegate {
    private let manager: ClipboardManager
    private let service: OCRService
    private let panel = ShelfDetailPanel()
    private let panelSize = NSSize(width: 640, height: 480)

    private var anchor: NSRect?
    private var edge: ClipboardShelfEdge = .top
    private var keepsShelfKey = false
    private var isOverlayVisible = false

    var presentInShelfOverlay: ((
        AnyView,
        CGSize,
        NSRect,
        ClipboardShelfEdge
    ) -> Void)?
    var dismissShelfOverlay: (() -> Void)?

    var onTranslateText: ((
        String,
        String,
        NSRect,
        ClipboardShelfEdge
    ) -> Void)?
    var onSaveSnippet: ((String) -> Void)?

    var isVisible: Bool {
        isOverlayVisible || panel.isVisible
    }

    init(manager: ClipboardManager, service: OCRService) {
        self.manager = manager
        self.service = service
        super.init()
        panel.delegate = self
    }

    func present(
        item: ClipboardItem,
        imageURL: URL,
        translateAfterRecognition: Bool,
        anchor: NSRect,
        edge: ClipboardShelfEdge,
        keepShelfKey: Bool = false
    ) {
        self.anchor = anchor
        self.edge = edge
        self.keepsShelfKey = keepShelfKey
        panel.allowsKey = !keepShelfKey

        service.onAutoTranslate = { [weak self] text, title in
            guard let self,
                  self.isVisible,
                  let anchor = self.anchor
            else {
                return
            }
            self.hide()
            self.onTranslateText?(text, title, anchor, self.edge)
        }
        service.present(
            item: item,
            imageURL: imageURL,
            translateAfterRecognition: translateAfterRecognition
        )

        let view = OCRPaneView(
            service: service,
            onCopyText: { [weak self] text in
                _ = self?.manager.copyTextToPasteboard(text)
            },
            onTranslate: { [weak self] text in
                guard let self, let anchor = self.anchor else { return }
                let source = self.service.sourceTitle
                let title = source.isEmpty
                    ? L("图片文字")
                    : L("图片文字 · %@", source)
                self.hide()
                self.onTranslateText?(text, title, anchor, self.edge)
            },
            onSaveSnippet: { [weak self] text in
                self?.onSaveSnippet?(text)
            },
            onClose: { [weak self] in
                self?.hide()
            },
            showsScrim: false
        )
        .frame(width: panelSize.width, height: panelSize.height)

        if keepShelfKey, let presentInShelfOverlay {
            presentInShelfOverlay(AnyView(view), panelSize, anchor, edge)
            isOverlayVisible = true
            return
        }

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
        if keepShelfKey {
            panel.orderFrontRegardless()
        } else {
            NSApp.activate()
            panel.makeKeyAndOrderFront(nil)
            panel.orderFrontRegardless()
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(
                controlPoints: 0.16, 1, 0.3, 1
            )
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        if isOverlayVisible {
            isOverlayVisible = false
            service.close()
            dismissShelfOverlay?()
            return
        }
        guard panel.isVisible else { return }
        service.close()
        panel.orderOut(nil)
        panel.alphaValue = 1
        panel.contentView = nil
    }

    func close() {
        hide()
    }

    func windowDidResignKey(_ notification: Notification) {
        guard !keepsShelfKey else { return }
        hide()
    }
}
