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

    var onTranslateText: ((
        String,
        String,
        NSRect,
        ClipboardShelfEdge
    ) -> Void)?
    var onSaveSnippet: ((String) -> Void)?

    var isVisible: Bool {
        panel.isVisible
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
        edge: ClipboardShelfEdge
    ) {
        self.anchor = anchor
        self.edge = edge

        service.onAutoTranslate = { [weak self] text, title in
            guard let self,
                  self.panel.isVisible,
                  let anchor = self.anchor
            else {
                return
            }
            self.onTranslateText?(text, title, anchor, self.edge)
            self.hide()
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
                self.onTranslateText?(text, title, anchor, self.edge)
                self.hide()
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
        service.close()
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
