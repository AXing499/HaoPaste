//
//  ScreenshotOCRPanelController.swift
//  HaoPaste
//
//  Centered OCR pane for a freshly captured screenshot.
//

import AppKit
import SwiftUI

@MainActor
final class ScreenshotOCRPanelController: NSObject, NSWindowDelegate {
    private let manager: ClipboardManager
    private let service: OCRService
    private let panel = ScreenshotOCRPanel()
    private let panelSize = NSSize(width: 640, height: 480)

    private var imageURL: URL?
    private var onTranslateText: ((String, String) -> Void)?
    private var onSaveSnippet: ((String) -> Void)?
    private var onHide: (() -> Void)?

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
        imageURL: URL,
        width: Int,
        height: Int,
        onTranslateText: @escaping (String, String) -> Void,
        onSaveSnippet: @escaping (String) -> Void,
        onHide: @escaping () -> Void
    ) {
        self.imageURL = imageURL
        self.onTranslateText = onTranslateText
        self.onSaveSnippet = onSaveSnippet
        self.onHide = onHide

        let item = ClipboardItem(
            type: .image,
            content: imageURL.lastPathComponent,
            plainText: "",
            contentHash: "screenshot-\(UUID().uuidString)",
            imageFileName: imageURL.lastPathComponent,
            thumbnailFileName: imageURL.lastPathComponent,
            imageDimensions: ImageDimensions(width: width, height: height)
        )
        service.present(item: item, imageURL: imageURL)
        service.sourceTitle = L("截图")

        let view = OCRPaneView(
            service: service,
            onCopyText: { [weak self] text in
                _ = self?.manager.copyTextToPasteboard(text)
            },
            onTranslate: { [weak self] text in
                guard let self else { return }
                let title = L("截图文字")
                self.onTranslateText?(text, title)
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

        let screen = NSScreen.screens.first {
            $0.frame.contains(NSEvent.mouseLocation)
        } ?? NSScreen.main ?? NSScreen.screens.first
        if let screen {
            let x = screen.visibleFrame.midX - panelSize.width / 2
            let y = screen.visibleFrame.midY - panelSize.height / 2
            panel.setFrame(
                NSRect(
                    x: x.rounded(.down),
                    y: y.rounded(.down),
                    width: panelSize.width,
                    height: panelSize.height
                ),
                display: false
            )
        }

        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    func hide() {
        guard panel.isVisible else { return }
        service.close()
        panel.orderOut(nil)
        panel.contentView = nil

        let imageURL = self.imageURL
        self.imageURL = nil
        self.onTranslateText = nil
        self.onSaveSnippet = nil
        let onHide = self.onHide
        self.onHide = nil

        if let imageURL {
            try? FileManager.default.removeItem(at: imageURL)
        }
        onHide?()
    }

    func close() {
        hide()
    }

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }
}

private final class ScreenshotOCRPanel: NSPanel {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .popUpMenu
        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenAuxiliary
        ]
        hidesOnDeactivate = false
        isMovable = false
        isReleasedWhenClosed = false
        becomesKeyOnlyIfNeeded = true
        animationBehavior = .none
        acceptsMouseMovedEvents = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
